# Usage

## Encode

    python3 encode.py -p [PATH] OPTIONAL_ARGS

#### Required Arguments

Short | Long | Description | Default
----- | ---- | ----------- | --------
-p | --path | Input path | None

#### Optional Arguments

Short | Long | Description | Default
----- | ---- | ----------- | --------
-o | --output | Output path (w/ file) | {WORKING_DIR}/vidqr.gif
-v | --version | QR Code version (1 to 40) | 20
-e | --errcorrect | Error correction level (0 to 3) | 0
-f | --fps | Framerate of GIF | 5
-fl | --flash | GIF flashes between loops | false
-r | --redundancy | Frame interval to insert redundant frames | 5
-rf | --redundantframes | # of redundant frames at each interval | 2

### Examples:

Basic:

    python encode.py -p sunset.png

Full:

    python encode.py -p sunset.png -o codes/sunset.gif -v 5 -e 1 -f 6 -fl true
