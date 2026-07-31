import os
import re
import requests
from difflib import SequenceMatcher

LIST_URL = "https://onyxv2.lol/Animations.lua"
OUTPUT_FOLDER = os.path.join(".", "animations")
SIMILARITY_THRESHOLD = 0.85


def normalize_name(name):
    name = os.path.splitext(name)[0].lower()
    name = re.sub(r"\s*\(\d+\)$", "", name)
    name = re.sub(r"\s*-\s*copy$", "", name)
    name = re.sub(r"\s+copy$", "", name)
    return name.strip()


def find_similar_file(folder, filename):
    target = normalize_name(filename)

    for existing in os.listdir(folder):
        full_path = os.path.join(folder, existing)

        if not os.path.isfile(full_path):
            continue

        existing_normalized = normalize_name(existing)

        if target == existing_normalized:
            return existing

        similarity = SequenceMatcher(
            None,
            target,
            existing_normalized
        ).ratio()

        if similarity >= SIMILARITY_THRESHOLD:
            return existing

    return None


def main():
    print("=" * 50)
    print("Animation Downloader")
    print("=" * 50)

    # Create animations folder
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    print(f"\nSaving to:")
    print(os.path.abspath(OUTPUT_FOLDER))

    print("\nGetting animation list...")
    print(f"URL: {LIST_URL}")

    try:
        response = requests.get(LIST_URL, timeout=30)

        print(f"HTTP Status: {response.status_code}")

        response.raise_for_status()

        lua = response.text

        print(f"Received {len(lua)} characters")

    except Exception as e:
        print("\nFAILED TO GET ANIMATION LIST")
        print(e)
        input("\nPress Enter to exit...")
        return

    # Extract filenames and URLs
    pattern = r'\["(.*?)"\]\s*=\s*"(.*?)"'
    files = re.findall(pattern, lua)

    print(f"\nFound {len(files)} animations")

    if len(files) == 0:
        print("\nWARNING: No animations were found!")
        print("\nThe website returned:")
        print(lua[:1000])

        input("\nPress Enter to exit...")
        return

    print("\n" + "=" * 50)

    downloaded = 0
    skipped = 0
    failed = 0

    for index, (filename, url) in enumerate(files, 1):

        print(f"\n[{index}/{len(files)}]")
        print(f"Name: {filename}")
        print(f"URL:  {url}")

        # Check for existing file
        similar = find_similar_file(
            OUTPUT_FOLDER,
            filename
        )

        if similar:
            print(f"SKIPPED")
            print(f"Similar file already exists: {similar}")

            skipped += 1
            continue

        try:
            print("Downloading...")

            file_response = requests.get(
                url,
                timeout=30
            )

            print(f"HTTP Status: {file_response.status_code}")
            print(f"Downloaded: {len(file_response.content)} bytes")

            file_response.raise_for_status()

            filepath = os.path.join(
                OUTPUT_FOLDER,
                filename
            )

            with open(filepath, "wb") as f:
                f.write(file_response.content)

            print(f"SAVED: {filepath}")

            downloaded += 1

        except Exception as e:
            print(f"DOWNLOAD FAILED: {e}")
            failed += 1

    print("\n" + "=" * 50)
    print("FINISHED")
    print("=" * 50)

    print(f"Downloaded: {downloaded}")
    print(f"Skipped:    {skipped}")
    print(f"Failed:     {failed}")

    print("\nFiles are located at:")
    print(os.path.abspath(OUTPUT_FOLDER))

    input("\nPress Enter to exit...")


if __name__ == "__main__":
    main()