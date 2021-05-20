#Packages
import argparse
import qrcode
import cv2
import os
from PIL import Image
from barcode import Code128
from barcode.writer import ImageWriter
from pyzbar import pyzbar
from pyzbar.pyzbar import ZBarSymbol
import numpy as np
import binascii
import math
import time
import sys
import numpy
import random

parser = argparse.ArgumentParser(description='Retrieve options dates for a given stock')
parser.add_argument('-p', '--path',default="",help="**REQUIRED** Input Path")
parser.add_argument('-o', '--output',default="vidqr",help="Output Path [optional; default {WORKING_DIR}/vidqr.gif]")
parser.add_argument('-v', '--version',default="20",help="Version btwn 1 and 40 [optional, default 10]")
parser.add_argument('-e', '--errcorrect',default="0",help="Error correction level btwn 0 (low) and 3 (high) [optional; default 0]")
parser.add_argument('-f', '--fps',default="5",help="Framerate [optional; defualt 5]")
parser.add_argument('-fl', '--flash',default="false",help="Animation flashes at every loop [optional; default false]")
parser.add_argument('-r', '--redundancy',default="0",help="Animation flashes at every loop [optional; default false]")
parser.add_argument('-rf', '--redundantframes',default="0",help="number of same redundant frames (pauses) per interval")
args = parser.parse_args()

version = 2

#Number of bytes that can be stored for each QR code version at each err correction level
capacity = [[17,14,11,7],
[32,26,20,14],
[53,42,32,24],
[78,62,46,34],
[106,84,60,44],
[134,106,74,58],
[154,122,86,64],
[192,152,108,84],
[230,180,130,98],
[271,213,151,119],
[321,251,177,137],
[367,287,203,155],
[425,331,241,177],
[458,362,258,194],
[520,412,292,220],
[586,450,322,250],
[644,504,364,280],
[718,560,394,310],
[792,624,442,338],
[858,666,482,382],
[929,711,509,403],
[1003,779,565,439],
[1091,857,611,461],
[1171,911,661,511],
[1273,997,715,535],
[1367,1059,751,593],
[1465,1125,805,625],
[1528,1190,868,658],
[1628,1264,908,698],
[1732,1370,982,742],
[1840,1452,1030,790],
[1952,1538,1112,842],
[2068,1628,1168,898],
[2188,1722,1228,958],
[2303,1809,1283,983],
[2431,1911,1351,1051],
[2563,1989,1423,1093],
[2699,2099,1499,1139],
[2809,2213,1579,1219],
[2953,2331,1663,1273]]

startTime = time.time()

permanentPrint = "" #Text intended to remain after clearing console

#Binary data of input file stored as a Base64 string
paragraph = ""

filetype = "txt"

#METADATA - Stored in Code128 Barcode
extension = os.path.splitext(args.path)[1].replace(".","") #Store extension of input file for decoding
versionOfCode = int(args.version)
originalSize = os.path.getsize(args.path)
redundancyInterval = int(args.redundancy);
framerate = int(args.fps)
errorCorrection = int(args.errcorrect)
errCorrectConstant = qrcode.constants.ERROR_CORRECT_L
redundantFrames = int(args.redundantframes);
flashes = bool(args.flash)

if errorCorrection == 1:
    errCorrectConstant = qrcode.constants.ERROR_CORRECT_M
elif errorCorrection == 2:
    errCorrectConstant = qrcode.constants.ERROR_CORRECT_Q
elif errorCorrection >= 3:
    errCorrectConstant = qrcode.constants.ERROR_CORRECT_H

#Create ASCII percentage bar
def percentageBar(value,max):
    outputString = "["
    percent = round((value / max) * 100)

    terminalWidth = os.get_terminal_size().columns - 10

    if terminalWidth > 100:
        terminalWidth = 100

    ticks = round(percent / (100 / terminalWidth))
    for index in range(0,terminalWidth):
        if index == round(terminalWidth / 2):
            outputString = outputString + " " + str(percent) + "% "
        elif index < ticks:
            outputString = outputString + "*"
        else:
            outputString = outputString + " "
    outputString = outputString + "] "
    return outputString

#Clear display but leave permanent text if desired
def clearConsole(includePermanent=True):
    global permanentPrint
    print("\033c")
    if includePermanent == True:
        print(permanentPrint)
        print("--------------------")

#Generate Code128 barcode with string data
def generateCode128(dataString):
    code128Barcode = Code128(dataString, writer=ImageWriter())
    #TODO: Directly save barcode to variable instead of writing then reading
    pilImage = code128Barcode.render()
    return cv2.cvtColor(numpy.array(pilImage).astype(np.uint8), cv2.COLOR_RGB2BGR)

def convertPilToCV(pilImg):
    pilImg.save("tmp/pil.png")
    cvImg = cv2.imread("tmp/pil.png")
    os.remove("tmp/pil.png")
    return cvImg

#Generate QR code with desired data
def generateQR(data):
    global versionOfCode, errCorrectConstant, permanentPrint

    #Generate QR as a pil image
    qr = qrcode.QRCode(version=versionOfCode,error_correction=errCorrectConstant)
    qr.add_data(data)
    pilQR = qr.make_image()

    #Return a CV image
    return convertPilToCV(pilQR)

#Encode Base64 fragments into array of QR code images
def generateCodesFromArray(dataArray):
    global numberOfCodes
    newImageArray = []
    for dataIndex in range(0,len(dataArray)):
        clearConsole()
        print("generating packets...")
        print(percentageBar(dataIndex + 1,len(dataArray)))
        print(str(dataIndex + 1) + " of " + str(len(dataArray)))

        #Create 4-byte (32-bit int) header for packet ID and encode to Base64
        header = binascii.b2a_base64((dataIndex + 1).to_bytes(4, byteorder = 'big'))[:-1]

        #Generate QR code with header and file data
        img = generateQR(header + dataArray[dataIndex])
        newImageArray.append(img)
    return newImageArray

#Attach constant barcode w/ important metadata below QR codes
def includeMetadataBarcode(qrCode, barCode, interpolation=cv2.INTER_CUBIC):
    qrHeight = qrCode.shape[0]
    qrWidth = qrCode.shape[1]

    #bcHeight * (qrWidth / bcHeight) = height scaled proportionally to new width
    bcHeight = int(qrWidth / 10)

    #Resize barcode to ensure its width matches the qr code height
    barCode = cv2.resize(barCode, (qrWidth,bcHeight), interpolation=cv2.INTER_CUBIC)

    return cv2.vconcat([qrCode,barCode])

#Used primarily as an (optional) indicator of the end of the series when looping
def generateBlankImage(h, w):
    a = np.full((h, w, 3), 255, dtype=np.uint8)
    image = Image.fromarray(a, "RGB")
    return image

def encode(inputPath,outputPath):
    global flashes, versionOfCode, errorCorrection, framerate, extension, originalSize, permanentPrint, redundancyInterval, redundantFrames
    bin_data = open(inputPath, 'rb').read() #read file as binary
    paragraph = binascii.b2a_base64(bin_data) #convert binary to Base64 string

    #Save copy of Base64 encoded binary for debugging purposes
    file = open('tmp/bin.txt', "wb")
    file.write(paragraph)
    file.close()

    #Calculate number of codes that need to be generated, taking size of header into account
    bytesPerCode = capacity[versionOfCode - 1][errorCorrection] - 8
    totalBytes = len(paragraph)
    numberOfCodes = math.ceil(totalBytes / bytesPerCode)

    permanentPrint = "File size: " + str(totalBytes) + " Bytes\nSize per Code: " + str(bytesPerCode) + " Bytes\nNumber of Codes: " + str(numberOfCodes)
    clearConsole()

    #Split file data into array of strings which is used to generate series of QR codes
    splitValues = [paragraph[i: i + bytesPerCode] for i in range(0, len(paragraph), bytesPerCode)]
    images = generateCodesFromArray(splitValues)

    permanentPrint = permanentPrint + "\n--------------------\ngenerating packets...done"
    clearConsole()

    #Add blank image to series so that the GIF animation flashes between every loop
    if flashes:
        #Create blank image with same dimensions as first image in packet array
        images.append(generateBlankImage(images[0].shape[0],images[0].shape[1]))

    #Final string stored in barcode
    metadata = str(version) + ":" + str(len(splitValues)) + ":" + extension + ":" + str(originalSize)
    metadataBarcode = generateCode128(metadata)
    if len(images) > 0:
        redundancyCounter = 0
        height, width, layers = includeMetadataBarcode(images[0],metadataBarcode).shape
        size = (width, height)
        out = cv2.VideoWriter(outputPath + '.mp4',cv2.VideoWriter_fourcc(*'h264'), framerate, size)

        #Encode image array into video, including redundant codes at tbe desired intervals
        for imageIndex in range(0,len(images) - 1):
            #Write next image to video
            clearConsole()
            print("generating video...")
            print(percentageBar(imageIndex, len(images)))
            out.write(includeMetadataBarcode(images[imageIndex],metadataBarcode))
            #Include random redundant code at the end
            #if (imageIndex % redundancyInterval == 0):
                #redundancyCounter += 1
                #if redundancyCounter >= len(images):
                    #redundancyCounter = 0
                #Multiple redundant frames essentially mimic a pause which increases likelihood
                #of decoder picking it up.
                #randomIndex = random.randint(0, len(images) - 2)
                #for frameIndex in range(0, redundantFrames):
                    #out.write(includeMetadataBarcode(images[randomIndex],metadataBarcode))

        out.release()

    permanentPrint = permanentPrint + "\ngenerating video...done"

    clearConsole()
    print("Saved vidQR code to " + os.getcwd() + "/" + outputPath + ".mp4")
    print("Time elapsed: " + str(math.ceil((time.time() - startTime) * 1000) / 1000) + " seconds");
    print("Encode speed: " + str(math.ceil((originalSize / (time.time() - startTime)) * 100) / 100000) + " KB/s");
    print("--------------------")

encode(args.path,args.output)
