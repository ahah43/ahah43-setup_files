import glob

for file in glob.glob("styles/*", recursive=True):  # noqa: F821
    file = file.replace("\\", "/")
    print(f'@import "{file}";')
