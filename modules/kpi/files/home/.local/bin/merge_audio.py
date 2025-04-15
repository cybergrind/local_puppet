#!/usr/bin/env python3
import argparse
import logging
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import List, Optional, Union


def find_matching_audio_file(video_stem: str, audio_files: List[Path]) -> Optional[Path]:
    """Find the best matching audio file for a given video file stem."""
    # First, try exact match
    for audio_file in audio_files:
        if audio_file.stem == video_stem:
            return audio_file

    # If no exact match, try looking for files with suffixes like .AL
    suffix_pattern = re.compile(rf'^{re.escape(video_stem)}\.\w+$')
    matches = [af for af in audio_files if suffix_pattern.match(af.stem)]

    if matches:
        if len(matches) > 1:
            logging.info(f"Multiple suffix matches found for '{video_stem}', using first match: '{matches[0].name}'")
        return matches[0]

    return None


def merge_audio_to_video(
    video_dir: Union[str, Path],
    audio_dir: Union[str, Path],
    tmp_dir: Optional[Union[str, Path]] = None,
    track_name: str = 'Russian',
    dry_run: bool = False,
) -> None:
    video_formats: List[str] = ['.mp4', '.mkv', '.avi', '.mov']  # Extend as needed
    audio_formats: List[str] = ['.mp3', '.mka', '.aac', '.flac']  # Extend as needed

    # Convert to Path objects
    video_dir = Path(video_dir)
    audio_dir = Path(audio_dir)

    video_files: List[Path] = [f for f in video_dir.iterdir() if f.is_file() and f.suffix.lower() in video_formats]
    audio_files: List[Path] = [f for f in audio_dir.iterdir() if f.is_file() and f.suffix.lower() in audio_formats]

    if not video_files:
        logging.warning('No video files found in the video directory.')
        return
    if not audio_files:
        logging.warning('No audio files found in the audio directory.')
        return

    # Use provided tmp_dir or create a temporary directory
    if tmp_dir:
        tmp_path = Path(tmp_dir)
        tmp_path.mkdir(parents=True, exist_ok=True)
    else:
        tmp_path = Path(tempfile.mkdtemp(prefix='mkvmerge_tmp_'))

    logging.info(f'Using temporary directory: {tmp_path}')

    for video_file in video_files:
        base_name: str = video_file.stem

        # Find matching audio file, handling potential suffixes
        matching_audio_file = find_matching_audio_file(base_name, audio_files)

        if not matching_audio_file:
            logging.warning(f"No matching audio file found for '{video_file.name}', skipping.")
            continue

        logging.info(f"Found matching audio file '{matching_audio_file.name}' for video '{video_file.name}'")

        # Prepare mkvmerge input arguments: start with video file
        inputs: List[str] = [str(video_file)]

        # Add only the matching audio file
        inputs.extend(['--track-name', f'0:{track_name}', str(matching_audio_file)])

        # Output filename in tmp dir, with .mkv extension
        output_tmp_file: Path = tmp_path / f'{base_name}_merged.mkv'

        command: List[str] = ['mkvmerge', '-o', str(output_tmp_file), *inputs]
        cmd_str = ' '.join(command)

        if dry_run:
            logging.info(f'DRY RUN: Would execute: {cmd_str}')
            logging.info(f'DRY RUN: Would replace {video_file} with {output_tmp_file}')
            continue

        logging.info(
            f"Merging audio '{matching_audio_file.name}' into '{video_file.name}' with track name '{track_name}'..."
        )
        try:
            subprocess.run(command, check=True)
            # Replace original video with merged file
            shutil.move(str(output_tmp_file), str(video_file))
            logging.info(f'Replaced original file with merged MKV: {video_file}')
        except subprocess.CalledProcessError as e:
            logging.error(f'Error merging {video_file.name}: {e}')
        except Exception as e:
            logging.error(f'Unexpected error: {e}')

    # Clean up tmp dir if it was created automatically
    if not dry_run and (not tmp_dir or str(tmp_path).startswith(tempfile.gettempdir())):
        try:
            shutil.rmtree(tmp_path)
            logging.info(f'Temporary directory {tmp_path} removed.')
        except Exception as e:
            logging.error(f'Could not remove temporary directory {tmp_path}: {e}')


def main() -> None:
    parser = argparse.ArgumentParser(description='Merge audio tracks into video files using mkvmerge.')
    parser.add_argument('video_dir', type=Path, help='Directory containing video files')
    parser.add_argument('audio_dir', type=Path, help='Directory containing audio files to add')
    parser.add_argument(
        '--tmp-dir',
        type=Path,
        default=Path(tempfile.gettempdir()) / 'mkvmerge_output',
        help='Temporary directory for intermediate files (defaults to system temp dir)',
    )
    parser.add_argument(
        '--track-name', type=str, default='Russian', help='Name for the audio track to be added (default: Russian)'
    )
    parser.add_argument('--dry-run', action='store_true', help='Print commands without executing them')
    parser.add_argument(
        '--log-level',
        default='INFO',
        type=str,
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
        help='Set logging level',
    )

    args = parser.parse_args()

    # Configure logging
    logging.basicConfig(level=getattr(logging, args.log_level), format='%(levelname)s: %(message)s')

    merge_audio_to_video(args.video_dir, args.audio_dir, args.tmp_dir, args.track_name, args.dry_run)


if __name__ == '__main__':
    main()
