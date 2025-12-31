import subprocess
import shutil
import os
from pathlib import Path

def run_command(cmd_list):
    """Run a shell command and return stdout text."""
    try:
        result = subprocess.run(cmd_list, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

def get_apt_packages():
    print("Scanning APT packages...")
    packages = []
    
    # Get list of manually installed packages
    manual_pkgs_output = run_command(['apt-mark', 'showmanual'])
    if not manual_pkgs_output:
        return []
        
    pkg_names = manual_pkgs_output.splitlines()
    
    # Get descriptions in bulk
    # Format: Package|Description (first line only)
    cmd = ['dpkg-query', '-W', '-f=${Package}|${Description}\n--ENTRY-DELIMITER--\n'] + pkg_names
    
    try:
        # We handle this manually to avoid "Argument list too long" if too many packages
        # Chunking if necessary, but for ~100-200 packages it should be fine.
        # For safety, let's chunk by 50.
        chunk_size = 50
        results = []
        for i in range(0, len(pkg_names), chunk_size):
            chunk = pkg_names[i:i + chunk_size]
            c_cmd = ['dpkg-query', '-W', '-f=${Package}|${Description}\n--ENTRY-DELIMITER--\n'] + chunk
            res = run_command(c_cmd)
            if res:
                results.append(res)
        
        full_output = "\n--ENTRY-DELIMITER--\n".join(results)
        entries = full_output.split('\n--ENTRY-DELIMITER--\n')
        
        for entry in entries:
            if not entry.strip(): continue
            parts = entry.split('|', 1)
            if len(parts) == 2:
                name = parts[0].strip()
                desc = parts[1].strip().split('\n')[0]
                packages.append({
                    'name': name,
                    'desc': desc,
                    'install': f"sudo apt-get install {name}",
                    'remove': f"sudo apt remove {name}"
                })
    except Exception as e:
        print(f"Error processing APT: {e}")
        
    return packages

def get_snap_packages():
    if not shutil.which('snap'):
        return []
    
    print("Scanning SNAP packages...")
    packages = []
    # snap list returns: Name Version Rev Tracking Publisher Notes
    # We want descriptions. 'snap info' gives description but is slow for many apps.
    # We will assume 'snap list' is sufficient to get names, and generic desc if info fails.
    
    output = run_command(['snap', 'list'])
    if not output:
        return []
        
    lines = output.splitlines()[1:] # Skip header
    for line in lines:
        parts = line.split()
        if not parts: continue
        name = parts[0]
        
        # Simple description default
        desc = f"Snap package: {name}"
        
        # Optional: Try to fetch real summary (can be slow)
        # info = run_command(['snap', 'info', name])
        # if info:
        #     for iline in info.splitlines():
        #         if iline.strip().startswith('summary:'):
        #             desc = iline.split(':', 1)[1].strip()
        #             break
        
        packages.append({
            'name': name,
            'desc': desc,
            'install': f"sudo snap install {name}",
            'remove': f"sudo snap remove {name}"
        })
    return packages

def get_flatpak_packages():
    if not shutil.which('flatpak'):
        return []

    print("Scanning FLATPAK packages...")
    packages = []
    # columns: name, application (id), description
    output = run_command(['flatpak', 'list', '--app', '--columns=name,application,description'])
    if not output:
        return []
        
    lines = output.splitlines()
    for line in lines:
        parts = line.split('\t')
        if len(parts) < 3: continue
        name = parts[0]
        app_id = parts[1]
        desc = parts[2]
        
        packages.append({
            'name': name,
            'desc': desc, # Flatpak descriptions are usually good one-liners
            'install': f"flatpak install {app_id}",
            'remove': f"flatpak uninstall {app_id}"
        })
    return packages

def get_manual_binaries():
    print("Scanning /usr/local/bin for manual installations...")
    packages = []
    target_dir = Path('/usr/local/bin')
    
    if not target_dir.exists():
        return []
        
    # Get all files in /usr/local/bin
    try:
        for item in target_dir.iterdir():
            if item.is_file() and os.access(item, os.X_OK):
                name = item.name
                packages.append({
                    'name': name,
                    'desc': f"Manual binary installation: {name}",
                    'install': f"# Manual download/build required for {name}",
                    'remove': f"sudo rm {item}"
                })
    except Exception as e:
        print(f"Error scanning source bins: {e}")
        
    return packages

def generate_md():
    all_packages = []
    all_packages.extend(get_apt_packages())
    all_packages.extend(get_snap_packages())
    all_packages.extend(get_flatpak_packages())
    all_packages.extend(get_manual_binaries())
    
    output_filepath = Path.home() / "/home/em/Downloads" / "installed_apps.md"
    with open(output_filepath, 'w') as f:
        for pkg in all_packages:
            f.write(f"# {pkg['desc']}\n")
            f.write(f"{pkg['install']}\n")
            f.write(f"{pkg['remove']}\n\n")
            
    print(f"Generated {output_filepath} with {len(all_packages)} entries.")

if __name__ == "__main__":
    generate_md()
