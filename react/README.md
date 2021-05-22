# vidQR React App

Cross platform solution to decoding vidQR codes.

Ideal for small (<50 KB) codes.

## Usage

Visit [vidqr.noahsadir.io](https://vidqr.noahsadir.io) and scan a code.

#### Alternatively, you can host the website yourself.

## Setup Environment

#### Note: Instructions assume Node.js and npm are installed on a Unix-based system with a properly configured LAMP stack.
 - Tested configuration: Ubuntu 18.04, Node 12.20.0, npm 6.14.8, Apache server 2.4.29, PHP 7.4.10

### How to set up
- Create an empty react app. These instructions assume the app is named "investalyze"
  ```
  npx create-react-app vidqr
  ```
- Download files from this folder (react) and copy into directory
  ```
  cd vidqr
  cp -r [DOWNLOADED_FOLDER]/* ./
  ```
- Install required packages:
  ```
  @zxing/library
  react-webcam
  ```
- (OPTIONAL) Build project or start in test environment to confirm that the code works
