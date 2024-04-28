# stitch-gear360
Stitching tool for 360° videos captured by the Samsung Gear 360 2017 (SM-R210)

## Usage

    ./stitch-gear360.sh [options] input1 input2 ... output

### Options

    -a, --refine-alignment  Enable alignment refinement.
    -f, --force             Bypass input filename validation.
    -h, --help              Print this help page and exit.
    -l, --compensate-light  Enable light compensation.

The resolution of the input files are ignored and rescaled to the correct size that the program expects.
After all the input files are combined, the audio is extracted from the file into a temporary mp3 file.
After the video goes through the fisheyeStitcher, which removes the audio, it is re-inserted back into the file.

If multiple input videos are specified, they will be joined together to one long output file.

The output file must be an .mp4 file.

## Dependencies

- ncurses
- ffmpeg
- bash
- [fisheyeStitcher](https://github.com/drNoob13/fisheyeStitcher)
- [spatial-media tools](https://github.com/google/spatial-media/)
- [grid_xd_yd_3840x1920.yml.gz](https://github.com/drNoob13/fisheyeStitcher/blob/master/utils/grid_xd_yd_3840x1920.yml.gz) located within `/usr/share/fisheye-stitcher`

The script assumes that you have `spatialmedia` on your PATH. If you do not have it, create an executable file on your PATH (e.g. `/usr/local/bin/spatialmedia`) with the following contents:

```sh
#!/bin/sh
python -m spatialmedia $@
```

## Thanks

Thanks a lot to drNoob13 for his project fisheyeStitcher. This script is merely a wrapper around that project.
Likewise thanks to bilde2910 for his original script.

