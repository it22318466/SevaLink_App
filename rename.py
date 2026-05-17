import os

def replace_in_file(filepath, old_str, new_str):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        if old_str in content:
            content = content.replace(old_str, new_str)
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Updated {filepath}")
    except Exception as e:
        pass

def main():
    root_dir = r"d:\dev\SevaLink\sevalink-app"
    old_str = "sevalink_app_temp"
    new_str = "sevalink_app"
    
    for dirpath, _, filenames in os.walk(root_dir):
        if ".git" in dirpath or ".dart_tool" in dirpath or "build" in dirpath:
            continue
        for filename in filenames:
            filepath = os.path.join(dirpath, filename)
            replace_in_file(filepath, old_str, new_str)

    # Rename android package folder
    old_pkg_dir = os.path.join(root_dir, "android", "app", "src", "main", "kotlin", "com", "example", "sevalink_app_temp")
    new_pkg_dir = os.path.join(root_dir, "android", "app", "src", "main", "kotlin", "com", "example", "sevalink_app")
    
    if os.path.exists(old_pkg_dir):
        os.rename(old_pkg_dir, new_pkg_dir)
        print(f"Renamed {old_pkg_dir} to {new_pkg_dir}")

if __name__ == "__main__":
    main()
