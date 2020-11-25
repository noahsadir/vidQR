# vidQR Python Scripts

## Usage

### Encode

    python3 encode.py -p [PATH] OPTIONAL_ARGS

#### Arguments

Short | Long | Description | Default
----- | ---- | ----------- | --------
-p | --path | Input Path | None
-o | --output | Output Path | {WORKING_DIR}/vidqr.gif
-v | --version | QR Code Version (1 through 40) | 10
-e | --errcorrect | Error correction level (0 to 3) | 0
-f | --fps | Framerate of GIF | 5
-fl | --flash | Flashes between loops | false
