# vidQR Python Scripts

## Usage

### Encode

    python3 encode.py -p [PATH] OPTIONAL_ARGS

#### Arguments

Short | Long | Description | Default
----- | ---- | ----------- | --------
-p | --path | Input path | None
-o | --output | Output path | {WORKING_DIR}/vidqr.gif
-v | --version | QR Code version (1 to 40) | 10
-e | --errcorrect | Error correction level (0 to 3) | 0
-f | --fps | Framerate of GIF | 5
-fl | --flash | GIF flashes between loops | false
