# vidQR React App

Cross platform solution to decoding vidQR codes.

Ideal for small (<50 KB) codes.

## Usage

Visit [vidqr.noahsadir.io](https://vidqr.noahsadir.io) and scan a code.

#### Alternatively, you can host the website yourself.

## Setup Environment

#### Note: Instructions assume Node.js and npm are installed on a Unix-based system with a properly configured LAMP stack.
 - Tested configuration: Ubuntu 18.04, Node 12.20.0, npm 6.14.8, Apache server 2.4.29, PHP 7.4.10

### Automated Install
 - In the parent folder of where you want to set up the environment, download the following script:
   ```
   wget https://noahsadir.io/resources/scripts/vidqr-react-install.sh
   ```
 - Inspect the script, then run:
   ```
   sh vidqr-react-install.sh
   ```
Alternatively, you can set up the environment manually.

### Manual Install
- Create an empty react app. These instructions assume the app is named "investalyze"
  ```
  npx create-react-app vidqr
  ```
- Navigate to react app and clone repository into temporary directory.
  ```
  cd vidqr
  git clone https://github.com/noahsadir/vidQR.git ./tmp
  ```
- Overwrite files created by create-react-app with those from repository, then delete temp folder
  ```
  # RUN COMMANDS BELOW WITH CAUTION
  cp -r tmp/* ./
  rm -r ./tmp
  ```
- Install required packages:
  ```
  @zxing/library
  react-webcam
  ```
- (OPTIONAL) Build project or start in test environment to confirm that the code works
