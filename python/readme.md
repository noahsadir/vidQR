# vidQR Python Scripts

## Usage

### Encode

    python3 encode.py -p [PATH] OPTIONAL_ARGS

Examples:

    python3 encode.py -p sunset.png

    python3 encode.py -p sunset.png -o codes/sunset.gif -v 5 -e 1 -f 6 -fl true

Short | Long | Description | Default
----- | ---- | ----------- | --------
-p | --path | Input path | None
-o | --output | Output path (w/ file) | {WORKING_DIR}/vidqr.gif
-v | --version | QR Code version (1 to 40) | 10
-e | --errcorrect | Error correction level (0 to 3) | 0
-f | --fps | Framerate of GIF | 5
-fl | --flash | GIF flashes between loops | false

### Decode

    python3 encode.py -p [PATH] OPTIONAL_ARGS

Examples:

    python3 decode.py -p sunset.mp4

    python3 decode.py -p sunset.mp4 -o ~/Documents -n sunset -v true

Short | Long | Description | Default
----- | ---- | ----------- | --------
-p | --path | Input path | None
-o | --output | Output folder (w/o file) | {WORKING_DIR}
-n | --name | Output file name (w/o extension) | output
-v | --verbose | Display debug messages | false
