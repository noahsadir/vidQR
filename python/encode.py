import argparse
import qrcode
import cv2
import os
import codecs
import imageio
from PIL import Image
from barcode import Code128
from barcode import EAN13
from barcode.writer import ImageWriter
from pyzbar import pyzbar
from pyzbar.pyzbar import ZBarSymbol
import numpy as np
import binascii
import math
import time
import sys

parser = argparse.ArgumentParser(description='Retrieve options dates for a given stock')
parser.add_argument('-p', '--path',default="",help="File Path")
parser.add_argument('-o', '--output',default="data/data.gif",help="File Path")
parser.add_argument('-v', '--version',default="10",help="File Path")
parser.add_argument('-e', '--errcorrect',default="0",help="File Path")
parser.add_argument('-f', '--fps',default="10",help="File Path")
parser.add_argument('-b', '--binary',default="true",help="File Path")
parser.add_argument('-fl', '--flash',default="true",help="File Path")
args = parser.parse_args()


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

def binToAscii(binary):
    ascii = ""
    for binaryItem in binary:
        ascii = ascii + chr(int(binaryItem))
    return ascii

def blackAndWhite(img,th=127):
    if img is not None:
        originalImage = img
        grayImage = cv2.cvtColor(originalImage, cv2.COLOR_BGR2GRAY)
        (thresh, blackAndWhiteImage) = cv2.threshold(grayImage, th, 255, cv2.THRESH_BINARY)
        return blackAndWhiteImage
    return img

def readPacketID(img,th=127):
    img = blackAndWhite(img,th)
    barcodes = pyzbar.decode(Image.fromarray(img), symbols=[ZBarSymbol.EAN13])
    if len(barcodes) >= 1:
        return int(barcodes[0].data.decode('utf-8'))
    return 0

def barcodeOfInt(intVal):
    qrc = qrcode.QRCode(version=1,error_correction=errCorrectConstant)
    qrc.add_data(str(intVal))
    qrc.make()
    qrc.make_image().save("tmp/bc" + str(intVal) + ".png")
    #number = str(intVal)
    #for i in range(len(number),12):
        #number =  "0" + number
    #my_code = EAN13(number, writer=ImageWriter())
    #my_code.save("tmp/bc" + str(intVal), options={"write_text": False})

def genQR(data):
    qr = qrcode.QRCode(version=versionOfCode,error_correction=errCorrectConstant)
    qr.add_data(data)
    qr.make()
    return qr.make_image()

def percentageBar(value,max):
    outputString = "["
    percent = round((value / max) * 100)
    ticks = round(percent / 2)
    for index in range(0,50):
        if index < ticks:
            outputString = outputString + "*"
        else:
            outputString = outputString + " "
    outputString = outputString + "] " + str(percent) + "%"
    return outputString

def joinImages(qrCode, barCode, interpolation=cv2.INTER_CUBIC):
    w_min = qrCode.shape[1]
    barCode = cv2.resize(barCode, (800,100), interpolation=cv2.INTER_CUBIC)
    qrCode = cv2.resize(qrCode, (800,800), interpolation=cv2.INTER_CUBIC)
    #index = cv2.resize(index, (int(index.shape[0] * w_min / qrCode.shape[1]), int(index.shape[0] * w_min / qrCode.shape[1])), interpolation=cv2.INTER_CUBIC)
    #barCode = cv2.resize(barCode, (index.shape[0] - int(barCode.shape[0] * w_min / qrCode.shape[1]), int(barCode.shape[0] * w_min / qrCode.shape[1])), interpolation=interpolation)
    #qrCode = cv2.resize(qrCode, (w_min, int(qrCode.shape[0] * w_min / qrCode.shape[1])), interpolation=interpolation)

    return cv2.vconcat([qrCode,barCode])

startTime = time.time()
paragraph = ""
filetype = "txt"
extension = os.path.splitext(args.path)[1].replace(".","")
versionOfCode = int(args.version)
errorCorrection = int(args.errcorrect)
if errorCorrection < 0:
    errorCorrection = 0
elif errorCorrection > 3:
    errorCorrection = 3

print(extension)
bin_data = open(args.path, 'rb').read()
filetype = "bin"

d = "".join(map(chr, bin_data))
paragraph = binascii.b2a_base64(bin_data)

file = open('data/bin.txt', "wb")
file.write(paragraph)
file.close()

bytesPerCode = capacity[versionOfCode - 1][errorCorrection] - 8
totalBytes = len(paragraph)
numberOfCodes = math.ceil(totalBytes / bytesPerCode)

print("File size: " + str(totalBytes) + " Bytes")
print("Bytes per code: " + str(bytesPerCode))
print("Number of codes: " + str(numberOfCodes))
print("\n---------------------\n")
file = open('data/raw.txt', "wb")
file.write(paragraph)
file.close()

x = bytesPerCode
print("Capacity: " + str(x) + " Bytes")



splitValues = [paragraph[i: i + x] for i in range(0, len(paragraph), x)]
print(splitValues)
for splitValue in splitValues:
    print(len(splitValue))
count = 0
images = []
framerate = int(args.fps)
version = 3

originalSize = os.path.getsize(args.path)

errCorrectConstant = qrcode.constants.ERROR_CORRECT_L
if errorCorrection == 1:
    qrcode.constants.ERROR_CORRECT_M
elif errorCorrection == 2:
    qrcode.constants.ERROR_CORRECT_Q
elif errorCorrection == 3:
    qrcode.constants.ERROR_CORRECT_H

barcodeData = str(framerate) + ":" + str(len(splitValues)) + ":" + extension + ":" + str(originalSize)
number = barcodeData
my_code = Code128(number, writer=ImageWriter())
my_code.save("data/barcode", options={"write_text": False})
barcode = cv2.imread("data/barcode.png")
barcode = cv2.resize(barcode, (barcode.shape[1], int(barcode.shape[0] / 4)), interpolation=cv2.INTER_CUBIC)

qrco = qrcode.QRCode(version=1,error_correction=errCorrectConstant)
qrco.add_data("NULL")
qrco.make()
qrco.make_image().save("tmp/bc_empty.png")


for frames in range(0,framerate):
    img = genQR("{vidqr}")
    #images.append(img)

#img.save("data/img_" + str(count) + ".png")
metadata = '{"e":"' + extension + '","v":' + str(version) + ',"p":' + str(len(splitValues)) + ',"f":' + str(framerate) + ',"s":' + str(originalSize) + ',"t":"' + filetype + '"}'
print("Metadata size: " + str(len(metadata)) + " Bytes")
if (len(metadata) > bytesPerCode):
    print("Error creating QR code. Try to increase the version or lower error correction")
    sys.exit()

print(metadata)
img = genQR(metadata)
#images.append(img)



count = 0
for splitValue in splitValues:
    count += 1
    print("\033c")
    print(percentageBar(count,len(splitValues)))
    print(str(count) + " of " + str(numberOfCodes))
    #print(str(count) + ":" + splitValue)
    #print("")
    header = binascii.b2a_base64(count.to_bytes(4, byteorder = 'big'))[:-1]
    print(binascii.a2b_base64(header))
    img = genQR(header + splitValue)
    images.append(img)
    #cv2.imwrite("data/img_" + str(count) + ".png", img)
    #img.save("data/img_" + str(count) + ".png")

count = 0
for image in images:
    count += 1
    image.save("tmp/" + str(count) + ".png")
    barcodeOfInt(count)


if args.flash == "true":
    count += 1
    img = cv2.imread('tmp/1.png')
    h, w, c = img.shape
    a = np.full((h, w, 3), 255, dtype=np.uint8)
    image = Image.fromarray(a, "RGB")
    image.save("tmp/" + str(count) + ".png", "PNG")

count += 1

images = []

for index in range(1,count):
    print("\033c")
    print("loaded " + str(index) + " of " + str(count))
    cv2.imwrite("tmp/new_" + str(index) + ".png",joinImages(cv2.imread("tmp/" + str(index) + ".png"),barcode))
    image = imageio.imread("tmp/new_" + str(index) + ".png")
    images.append(image)

print("\033c")
print("generating data.gif - " + str(count))
imageio.mimsave('data/data_v' + str(versionOfCode) + '.gif', images, fps=framerate)
duration = time.time() - startTime
totalSecs = round(duration,1)
transferSpeed = round(originalSize / totalSecs)
print("Duration: " + str(totalSecs) + " seconds")
print("Rate: " + str(transferSpeed) + " Bytes/sec")
