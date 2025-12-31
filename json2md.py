#!/usr/bin/env python3
"""
🚀 Professional AI Chat-to-Markdown Converter
Standardizes chat exports from OpenAI, Anthropic, DeepSeek, and others into clean, 
well-organized Markdown files for Obsidian or other knowledge bases.
"""

import json
import re
import argparse
import concurrent.futures
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List, Optional, Protocol, Tuple
from dataclasses import dataclass, field

@dataclass
class ChatMessage:
    role: str
    content: str
    timestamp: Optional[str] = None
    model: Optional[str] = None

@dataclass
class ChatThread:
    title: str
    messages: List[ChatMessage]
    metadata: Dict[str, Any] = field(default_factory=dict)
    
class ParsingStrategy(Protocol):
    def parse(self, data: Dict[str, Any]) -> List[ChatMessage]: ...
    def identify(self, data: Dict[str, Any]) -> bool: ...

# ====================================================================
# PARSING STRATEGIES
# ====================================================================

class OpenAIStrategy:
    def identify(self, data: Dict[str, Any]) -> bool:
        return 'mapping' in data and isinstance(data['mapping'], dict)

    def parse(self, data: Dict[str, Any]) -> List[ChatMessage]:
        messages = []
        mapping = data['mapping']
        
        # Sort by creation time if possible
        nodes = sorted(mapping.values(), key=lambda n: n.get('message', {}).get('create_time', 0) or 0)
        
        for node in nodes:
            msg = node.get('message')
            if not msg or not msg.get('content'): continue
            
            author = msg.get('author', {})
            role = author.get('role', 'unknown')
            model = author.get('metadata', {}).get('model_slug')
            
            parts = msg['content'].get('parts', [])
            content = " ".join([p for p in parts if isinstance(p, str)]).strip()
            
            if content:
                timestamp = msg.get('create_time')
                formatted_time = datetime.fromtimestamp(timestamp).isoformat() if timestamp else None
                messages.append(ChatMessage(role=role, content=content, timestamp=formatted_time, model=model))
        return messages

class AnthropicStrategy:
    def identify(self, data: Dict[str, Any]) -> bool:
        return 'chat_messages' in data and isinstance(data['chat_messages'], list)

    def parse(self, data: Dict[str, Any]) -> List[ChatMessage]:
        messages = []
        for m in data['chat_messages']:
            role = m.get('sender', 'unknown')
            content = m.get('text', '')
            timestamp = m.get('created_at')
            if content:
                messages.append(ChatMessage(role=role, content=content, timestamp=timestamp))
        return messages

class DeepSeekStrategy:
    def identify(self, data: Dict[str, Any]) -> bool:
        return 'chat' in data and 'messages' in data['chat']

    def parse(self, data: Dict[str, Any]) -> List[ChatMessage]:
        messages = []
        msg_dict = data.get('chat', {}).get('messages', {})
        # Sort by key if numeric IDs are used
        sorted_ids = sorted(msg_dict.keys(), key=lambda x: int(x) if x.isdigit() else x)
        
        for mid in sorted_ids:
            m = msg_dict[mid]
            role = m.get('role', 'unknown')
            content = m.get('content') or ""
            if not content and 'content_list' in m:
                # Handle complex content_list
                content = "\n".join([c.get('content', '') for c in m['content_list'] if isinstance(c, dict)])
            
            if content:
                messages.append(ChatMessage(role=role, content=content))
        return messages

# ====================================================================
# CONVERTER CORE
# ====================================================================

class ChatConverter:
    def __init__(self, output_dir: Path, style: str = "modern"):
        self.output_dir = Path(output_dir)
        self.style = style
        self.strategies: List[ParsingStrategy] = [
            OpenAIStrategy(),
            AnthropicStrategy(),
            DeepSeekStrategy()
        ]

    def _sanitize(self, filename: str) -> str:
        filename = re.sub(r'[<>:"/\\|?*]', '', filename)
        return filename[:50].strip().replace(' ', '_')

    def format_markdown(self, chat: ChatThread) -> str:
        lines = [f"# {chat.title}", ""]
        
        if chat.metadata:
            lines.append("## Metadata")
            for k, v in chat.metadata.items():
                if v: lines.append(f"- **{k.capitalize()}:** {v}")
            lines.append("")
            
        lines.append("---")
        
        for msg in chat.messages:
            role_label = msg.role.upper()
            time_label = f" *({msg.timestamp})*" if msg.timestamp else ""
            model_label = f" `[{msg.model}]`" if msg.model else ""
            
            lines.append(f"\n### 👤 {role_label}{model_label}{time_label}\n")
            
            # Formatting based on style
            if self.style == "code":
                lines.append("```markdown")
                lines.append(msg.content)
                lines.append("```")
            else:
                # Modern style - simple blocks
                lines.append(msg.content)
            lines.append("\n---")
            
        return "\n".join(lines)

    def process_entry(self, index: int, entry: Dict[str, Any]) -> Tuple[bool, str]:
        try:
            strategy = next((s for s in self.strategies if s.identify(entry)), None)
            if not strategy:
                return False, "Unknown format"
            
            messages = strategy.parse(entry)
            if not messages:
                return False, "No valid messages found"
            
            title = entry.get('title') or entry.get('name') or f"Chat_{index}"
            meta = {
                "created_at": entry.get('created_at'),
                "updated_at": entry.get('updated_at'),
                "id": entry.get('id')
            }
            
            chat = ChatThread(title=title, messages=messages, metadata=meta)
            md_content = self.format_markdown(chat)
            
            safe_title = self._sanitize(title)
            filename = self.output_dir / f"{safe_title}.md"
            
            # Simple unique fix
            counter = 1
            while filename.exists():
                filename = self.output_dir / f"{safe_title}_{counter}.md"
                counter += 1
            
            filename.write_text(md_content, encoding='utf-8')
            return True, str(filename.name)
            
        except Exception as e:
            return False, str(e)

def main():
    parser = argparse.ArgumentParser(description="Professional AI Chat-to-Markdown Converter")
    parser.add_argument("input", help="Source JSON file")
    parser.add_argument("-o", "--output", default="converted_chats", help="Output directory")
    parser.add_argument("--style", choices=["modern", "code"], default="modern", help="Formatting style")
    parser.add_argument("-p", "--parallel", action="store_true", help="Use parallel processing")
    
    args = parser.parse_args()
    
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"❌ File not found: {input_path}")
        return

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
        # Unified list of chats
        chat_list = data if isinstance(data, list) else data.get('data', [])
        if not isinstance(chat_list, list):
            print("❌ Root JSON is not a list and contains no 'data' list.")
            return

        print(f"📂 Processing {len(chat_list)} chat records...")
        converter = ChatConverter(output_dir, style=args.style)
        
        success = 0
        errors = 0
        
        if args.parallel:
            with concurrent.futures.ProcessPoolExecutor() as executor:
                futures = [executor.submit(converter.process_entry, i, chat) for i, chat in enumerate(chat_list)]
                for future in concurrent.futures.as_completed(futures):
                    ok, msg = future.result()
                    if ok: success += 1
                    else: errors += 1
        else:
            for i, chat in enumerate(chat_list):
                ok, msg = converter.process_entry(i, chat)
                if ok: 
                    success += 1
                    print(f"  ✓ {msg}", end="\r")
                else: 
                    errors += 1
                    print(f"  ❌ {msg}")

        print(f"\n\n✨ Conversion Complete!")
        print(f"  Processed: {success}")
        print(f"  Failed:    {errors}")
        print(f"  Target:    {output_dir.resolve()}")
        
    except Exception as e:
        print(f"💥 Fatal Error: {e}")

if __name__ == "__main__":
    main()