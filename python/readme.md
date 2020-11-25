# Usage

## Encode

    python3 encode.py -p [PATH] OPTIONAL_ARGS

### Required Arguments

Short | Long | Description | Default
----- | ---- | ----------- | --------
-p | --path | Input path | None

### Optional Arguments

Short | Long | Description | Default
----- | ---- | ----------- | --------
-o | --output | Output path (w/ file) | {WORKING_DIR}/vidqr.gif
-v | --version | QR Code version (1 to 40) | 10
-e | --errcorrect | Error correction level (0 to 3) | 0
-f | --fps | Framerate of GIF | 5
-fl | --flash | GIF flashes between loops | false

### Examples:

Basic:

    python3 encode.py -p sunset.png

Full:

    python3 encode.py -p sunset.png -o codes/sunset.gif -v 5 -e 1 -f 6 -fl true

## Decode

    python3 decode.py -p [PATH] OPTIONAL_ARGS

### Required Arguments

Short | Long | Description | Default
----- | ---- | ----------- | --------
-p | --path | Input path | None


### Optional Arguments

Short | Long | Description | Default
----- | ---- | ----------- | --------
-o | --output | Output folder (w/o file) | {WORKING_DIR}
-n | --name | Output file name (w/o extension) | output
-v | --verbose | Display debug messages | false

### Examples:

Basic:

    python3 decode.py -p sunset.mp4

Full:

    python3 decode.py -p sunset.mp4 -o ~/Documents -n sunset -v true
