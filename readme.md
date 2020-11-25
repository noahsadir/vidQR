# vidQR - Animated series of QR Codes

## Usage

See the individual folders for usage data specific to that program.

In general, put a file into an encoder to receive a vidQR code and scan that code with a decoder to retrieve the file back.

## Purpose

A single traditional QR code is immensely useful, but doesn't store that much data. This program attempts to address that issue (and introduces a whole host of new ones while doing so).

This is accomplished by breaking up a file into smaller pieces and turning each piece into a QR code, forming an animated series of codes that can be scanned and decoded.

Where as a QR code can store up to 3 kilobytes (and only a couple hundred before it becomes huge and unwieldy), vidQR can easily transmit up to a hundred KB of data and theoretically way, way more.

In essence, you can think of vidQR as a 3D barcode, with time being the third dimension.

## Technical Details

### Encoding

The input file is interpreted as a binary file and encoded to a Base64 string. That string is then split to fit into each QR code, which essentially act as packets.

The first 4 bytes stored in each QR code is a header containing ID of the packet (individual code) and the rest contains the actual file data.

After each QR code is generated, they are stitched together into a GIF which can then be scanned by a decoder.

Additionally, a static Code128 barcode is always present under each QR code which stores metadata and triggers the decoder to start scanning the QR codes.

### Decoding

The decoding program first searches for a Code128 barcode which contains the number of packets, file extension, file size, and frame rate of the GIF. Once the code is found and the metadata is stored, the program begins to scan and store the packets.

An array is created with pre-allocated indices for each packet data and another array is created to store the packet IDs for reference.

For each code detected by the scanner:
- The first 4 bytes of the code are interpreted as a 32-bit integer and compared against the packet ID array.
- If no matches are found (packet hasn't been stored yet), the remaining bytes of code are stored as a Base64 string in the appropriate index.

The program keeps scanning until each packet is stored. All the strings are combined (in order) into a single string and decoded back into binary, which is then stored as a file with the extension specified in the metadata.

## FAQ

### What are practical uses for this?

I have no idea. This is something I made out of sheer boredom and curiosity.

### What's the largest amount of data I can store with this?

Since the maximum storage capacity of a QR code (Version 40) is just over 3 KB and the packets are stored as a 32-bit integer, you could theoretically encode a 12TB file in 4,294,967,295 packets. Please don't do this.

### Why is the packet ID stored as a 32-bit int? Will you really need that many packets?

Probably not. I might change it to a 16-bit or 24-bit value.
