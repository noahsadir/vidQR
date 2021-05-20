# vidQR - Animated series of QR Codes

QR codes are great for transferring very small amounts of data (such as a URL or identifier) with an ordinary camera.

But what if you wanted to transfer more data, perhaps a small file, though a similar method? Even the biggest QR code can only store about 3 KB of data, and even that results in a very large and unwieldy QR code.

This "problem" can be solved by breaking up a file into smaller pieces and turning each piece into a QR code, forming a series of codes that can be scanned and decoded.

### Encoding (see 'python' folder for more info)

The binary of an input file is encoded as a Base64 string. That string is then split into substrings which can fit in a QR code.

#### VERSION 2
  - The first 4 bytes stored in each QR code is a header containing the ID of the packet
  - The remaining bytes contain the actual binary data

#### VERSION 3
  - The first 3 bytes stored in each QR code is 24-bit unsigned int containing the ID of the packet
  - The fourth byte is an 8-bit unsigned int representing the type of data stored in the packet (file data, metadata, etc.)
  - The remaining bytes contain the actual binary data

After each QR code is generated, they are stitched together into a video which can then be scanned by a decoder.

Additionally, a static Code128 barcode is always present under each QR code which stores metadata and triggers the decoder to start scanning the QR codes.

### Decoding (see 'react' or 'ios-app' folder for more info)

The decoding program first searches for a Code128 barcode which contains the number of packets, file extension, file size, and frame rate of the GIF. Once the code is found and the metadata is stored, the program begins to scan and store the packets.

An array is created with pre-allocated indices for each packet data and another array is created to store the packet IDs for reference.

For each code detected by the scanner:
- The first 4 bytes of the code are interpreted as a 32-bit integer and compared against the packet ID array.
- If no matches are found (packet hasn't been stored yet), the remaining bytes of code are stored as a Base64 string in the appropriate index.

The program keeps scanning until each packet is stored. All the strings are combined (in order) into a single string and decoded back into binary, which is then stored as a file with the extension specified in the metadata.

### Practical uses

None, probably.

### Limitations

  - The maximum storage capacity of a QR code (v40, low EC) is 2953 Bytes. There is a 33% overhead due to Base64, along with a 4-byte overhead due to the header, resulting in a maximum of about 2200 bytes of raw binary per code.

#### VERSION 2
  - The packet ID is stored as a 32-bit unsigned int, allowing for up to 4,294,967,296 packets. With 2200 bytes per code, this would allow for approximately 9 TB of data.

#### VERSION 3
  - The packet ID is stored as a 24-bit unsigned int, allowing for up to 16,777,216 packets. With 2200 bytes per code, this would allow for approximately 37 GB of data.

While Version 3 only takes advantage of packet types 0 (file data) and 1 (metadata), there can theoretically be up to 256 distinct packet "types". A future version could utilize this to split the packets into 255 groups of 37 GB each.

### Recommended Settings

The recommended settings are included in the defaults. I have found this to be the best one-size-fits-all configuration which maximizes speed, accuracy, and practicality. As of 5/20/2021, that is:
- Version 20 QR code (-v 20)
- 3 FPS (-f 3)
