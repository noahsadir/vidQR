import logo from './logo.svg';
import './App.css';
import React from 'react';
import { BrowserQRCodeReader, BrowserBarcodeReader, Result, BarcodeFormat, DecodeHintType } from '@zxing/library'
import Webcam from 'react-webcam'

var packets = [];
var extendedMetaPackets = [];

var packetsFound = 0;
var extendedMetaPacketsFound = 0;

var fileName = "file";
var fileExtension = "";
var downloadURL = "#";
var fileSize = 0;
var version = null;

var lastScan = 0;
var rejectedScans = 0;

var loadedData = false;
var loadedMetadata = false;

export default class App extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      theme: {
        backgroundColor: '#000004',
        textColor: '#ffffff',
        accentColor: '#1976d2',
      },
      loadedFile: {
        name: "file",
        url: "#",
        size: 0,
        filePackets: [],
        metaPackets: [],
      },
      currentView: "decoder_view",
      shouldScan: true,
    };
  }

  render() {

    const readerFinishedLoading = (url, fullFileName, filePackets, metaPackets) => {
      this.state.loadedFile.name = fullFileName;
      this.state.loadedFile.url = url;
      this.state.loadedFile.size = fileSize;
      this.state.loadedFile.filePackets = filePackets;
      this.state.loadedFile.metaPackets = metaPackets;
      this.state.shouldScan = false;
      this.state.currentView = "decoded_file_view";
      this.setState({state: this.state});
    }

    return (
      <div style={{display: 'flex', position: 'fixed', backgroundColor: this.state.theme.backgroundColor, color: this.state.theme.textColor, height: '100%', width: '100%'}}>
        <div style={{display: (this.state.currentView == "decoder_view" ? "flex" : "none")}}>
          <DecoderView shouldScan={this.state.shouldScan} theme={this.state.theme} onFinishedLoading={readerFinishedLoading}/>
        </div>
        <div style={{display: (this.state.currentView == "decoded_file_view" ? "flex" : "none"), width: "100%"}}>
          <DecodedFileView loadedFile={this.state.loadedFile} theme={this.state.theme}/>
        </div>
      </div>
    );
  }
}

//<a href={downloadURL} style={{display: (this.state.progress.loadedVidQR ? "block" : "none"), color: "#80d6ff"}} download={fileName + fileExtension}>Download File</a>
class DecodedFileView extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return (
      <div style={{display: "flex", flexFlow: "column", width: "100%"}}>
        <div style={{display: "flex", flex: "0 0 0"}}>
          <div style={{flex: "1 0 0"}}></div>
          <div style={{flex: "999 0 0"}}>
            <p style={{textAlign: "center", fontWeight: 600, fontSize: 24}}>Scan Successful</p>
            <p style={{textAlign: "center", fontSize: 18}}>{this.props.loadedFile.name}</p>
            <p style={{textAlign: "center", fontSize: 18}}>{this.props.loadedFile.size + " Bytes"}</p>
          </div>
          <div style={{flex: "1 0 0"}}></div>
        </div>
        <div style={{flex: "1 0 0"}}></div>
        <div style={{display: "flex", flex: "0 0 0", padding: 16, paddingBottom: 32}}>
          <div style={{flex: "1 0 0"}}></div>
          <a
            href={this.props.loadedFile.url}
            download={this.props.loadedFile.name}

            style={{
              maxWidth: 256,
              flex: "999 0 0",
              textAlign: "center",
              color: this.props.theme.textColor,
              backgroundColor: this.props.theme.accentColor,
              padding: 8,
              paddingTop: 16,
              paddingBottom: 16,
              borderRadius: 8,
              textDecoration: "none"
            }}>
              Save File
          </a>
          <div style={{flex: "1 0 0"}}></div>
        </div>
      </div>
    );
  }
}

class DecoderView extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      progress: {
        foundVidQR: false,
        loadedVidQR: false,
      },
      scanVal: -1,
    };
  }

  render() {

    if (this.props.shouldScan && this.state.progress.loadedVidQR && this.props.onFinishedLoading != null) {
      this.props.onFinishedLoading(downloadURL, fileName + fileExtension, packets, extendedMetaPackets);
    }

    const handleScan = (error, data) => {
      if (data) {
        if (this.state.progress.foundVidQR && this.state.progress.loadedVidQR == false) {
          var result = processQRCodeData(data, this.state);
          result.state.scanVal += 1;
          this.setState({state: result.state});
        } else if (this.state.progress.foundVidQR == false && this.state.progress.loadedVidQR == false) {
          var basicMetadata = getMetadata(data.text);
          if (basicMetadata != null) {
            saveBasicMetadata(basicMetadata);
            this.state.progress.foundVidQR = true;
            this.setState({state: this.state});
          } else {
            console.log("vidQR format not recognized");
          }
        }
      }
    }

    return (
      <div style={{display: 'flex', color: this.props.theme.textColor, backgroundColor: this.props.theme.backgroundColor, flexFlow: "column", position: 'fixed', width: '100%', height: '100%'}}>
        <div style={{position: "fixed", top: 0, bottom: 0, left: 0, right: 0, backgroundColor: '#ffffff', zIndex: 0}}>
          <VidQRReader
            height={"100%"}
            scanInterval={100}
            scanVal={this.state.scanVal}
            shouldScan={this.props.shouldScan}
            type={this.state.progress.foundVidQR ? "QR" : "CODE_128"}
            onUpdate={handleScan}
          />
        </div>
        <div style={{margin: 0, padding: 16, backgroundColor: "#000000AA", zIndex: 1}}>
          <p>{this.state.progress.foundVidQR ? "Scanning..." : "Searching for code"}</p>
          <p>{"Loaded " + packetsFound.toString() + " of " + packets.length.toString()}</p>
        </div>
      </div>
    );
  }
}

class VidQRReader extends React.Component {
  constructor(props) {
    super(props);
    this.webcamRef = React.createRef();
    this.capture = null;
  }

  componentDidMount() {
    setInterval(this.capture, this.props.scanInterval);
  }

  render() {
    const webcamRef = this.webcamRef;
    var barcodeReader = new BrowserBarcodeReader();
    var qrcodeReader = new BrowserQRCodeReader();

    const capture = () => {
      //Only scan if needed (for performance & privacy reasons)
      if (this.props.shouldScan) {
        if (this.props.scanVal != lastScan) {
          const imageSrc = webcamRef?.current?.getScreenshot()
          if (imageSrc) {
            //Decode barcode of desired type
            if (this.props.type == "QR") {
              qrcodeReader.decodeFromImage(undefined, imageSrc).then(result => {
                lastScan = this.props.scanVal;
                this.props.onUpdate(null, result)
              }).catch((err) => {
                this.props.onUpdate(err)
              })
            } else if (this.props.type == "CODE_128") {
              barcodeReader.decodeFromImage(undefined, imageSrc).then(result => {
                this.props.onUpdate(null, result)
              }).catch((err) => {
                this.props.onUpdate(err)
              })
            }
          }
        } else {
          rejectedScans += 1;
        }
      }
    }

    this.capture = capture;

    return (
      <Webcam
        width={this.props.width}
        height={this.props.height}
        ref={this.webcamRef}
        audio={false}
        imageSmoothing={false}
        screenshotFormat="image/png"
        videoConstraints={{
          facingMode: 'environment'
        }}
      />
    );
  }
}

function processQRCodeData(data, state) {
  var stateChanged = false;

  if (version == 2) {
    //Packet ID is stored in first 4 bits of packet as 32-bit big-endian unsigned integer
    var packetID = (new Buffer(data.text.substring(0,8), 'base64')).readUIntBE(0, 4);

    //Only load packet if not loaded already
    if (packets[packetID - 1] == null) {
      packets[packetID - 1] = data.text.substring(8);
      packetsFound += 1;

      //All packets found; form into file
      if (packetsFound == packets.length) {
        downloadURL = convertPacketsToDownloadableURL(packets);
        state.progress.loadedVidQR = true;
      }

      stateChanged = true;
    }
  } else if (version == 3) {

    //First 3 bytes make up 24-bit big-endian unsigned integer for packet ID
    var packetID = (new Buffer(data.text.substring(0, 4), 'base64')).readUIntBE(0, 3);

    //Next byte is a 1-bit unsigned int representing the type of packet
    var packetType = (new Buffer(data.text.substring(4, 8), 'base64')).readUIntBE(0, 1);

    if (packetType == 0 && !loadedData && packets[packetID - 1] == null) { //packetID 0: File data

      //Only load packet if not loaded already
      packets[packetID - 1] = data.text.substring(8); //Read all bytes past first four
      packetsFound += 1;

      //All packets found; form into file
      if (packetsFound == packets.length) {
        downloadURL = convertPacketsToDownloadableURL(packets);
        loadedData = true;
      }

      stateChanged = true;
    } else if (packetType == 1 && !loadedMetadata && extendedMetaPackets[packetID - 1] == null) { //packetID 1: Extended metadata
      //Only load packet if not loaded already
      extendedMetaPackets[packetID - 1] = data.text.substring(8);
      extendedMetaPacketsFound += 1;

      //All packets found; form into file
      if (extendedMetaPacketsFound == extendedMetaPackets.length) {
        var largeMetadata = convertPacketsToJSON(extendedMetaPackets);
        fileExtension = "." + largeMetadata.ext;
        fileName = largeMetadata.name;
        fileSize = largeMetadata.size;
        loadedMetadata = true;
      }

      stateChanged = true;
    }

    if (loadedData && loadedMetadata) {
      state.progress.loadedVidQR = true;
      stateChanged = true;
    }
  }
  return {stateChanged: stateChanged, state: state};
}

function vidQRVersion(metadata) {

  if (metadata[0] == "2" && metadata.length == 4) {
    return 2;
  } else if (metadata[0] == "3" && metadata.length == 3) {
    return 3;
  }

  return null;
}

function saveBasicMetadata(basicMetadata) {
  packets = [];
  extendedMetaPackets = [];

  packetsFound = 0;
  extendedMetaPacketsFound = 0;

  version = basicMetadata.version;

  //Populate array with null values indicating a packet which has yet to be found
  for (var i = 0; i < basicMetadata.packetCount; i++) {
    packets.push(null);
  }

  if (version == 3) {
    for (var i = 0; i < basicMetadata.metaCount; i++) {
      extendedMetaPackets.push(null);
    }
  }

  if (version == 2) {
    fileExtension = "." + basicMetadata.extension;
  }
}

function getMetadata(metadataString) {

  var metadataSplit = metadataString.split(":");
  var version = vidQRVersion(metadataSplit);

  if (version == 2) {
    return ({
      version: metadataSplit[0],
      packetCount: metadataSplit[1],
      extension: metadataSplit[2],
      fileSize: metadataSplit[3]
    });
  } else if (version == 3) {
    return ({
      version: metadataSplit[0],
      packetCount: metadataSplit[1],
      metaCount: metadataSplit[2],
    });
  }

  return null;
}

function convertPacketsToDownloadableURL(packetArray) {

  //Stitch together the QR codes
  var finalString = "";
  for (var index in packetArray) {
    finalString += packetArray[index];
  }

  //Convert base64 string into buffer and form it into a downloadable blob
  var dataBuffer = new Buffer(finalString, 'base64');
  var blob = new Blob([ dataBuffer ]);
  return window.URL.createObjectURL(blob);
}

function convertPacketsToJSON(packetArray) {
  //Stitch together the QR codes
  var finalString = "";
  for (var index in packetArray) {
    finalString += packetArray[index];
  }

  var dataBuffer = new Buffer(finalString, 'base64');

  return JSON.parse(dataBuffer.toString());
}
