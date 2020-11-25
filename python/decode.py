import cv2
import argparse
import qrcode
import numpy as np
import json
import os
import time
import binascii
from barcode import EAN13
from PIL import Image
from pyzbar import pyzbar
from pyzbar.pyzbar import ZBarSymbol
import sys

#Arguments
parser = argparse.ArgumentParser(description='Tool to decode a vidQR code')
parser.add_argument('-p', '--path',default="",help="File Path")
parser.add_argument('-o', '--output',default="",help="Output Path")
parser.add_argument('-v', '--verbose',default="",help="Show errors and diagnostics")
args = parser.parse_args()

verbose = False
if args.verbose == "true":
    verbose = True

#Load video from file path
vidcap = cv2.VideoCapture(args.path)

packets = 0

#convert CVimage to 2-color black and white with specified threshold
def blackAndWhite(img,th=127):
    if img is not None:
        originalImage = img
        grayImage = cv2.cvtColor(originalImage, cv2.COLOR_BGR2GRAY)
        (thresh, blackAndWhiteImage) = cv2.threshold(grayImage, th, 255, cv2.THRESH_BINARY)
        return blackAndWhiteImage
    return img

#Look for QR code in image and attempt to retrieve data
def readCode(img,th=127):
    global output
    img = blackAndWhite(img,th)
    codes = pyzbar.decode(Image.fromarray(img), symbols=[ZBarSymbol.QRCODE])
    if len(codes) >= 1:
        barcode_info = codes[0].data
        return barcode_info
    return None

def readPacketID(img,th=127):
    img = blackAndWhite(img,th)
    barcodes = pyzbar.decode(Image.fromarray(img), symbols=[ZBarSymbol.EAN13])
    if len(barcodes) >= 1:
        return int(barcodes[0].data.decode('utf-8')[:12])
    return -1

def readBarcode(img,th=127):
    img = blackAndWhite(img,th)
    barcodes = pyzbar.decode(Image.fromarray(img), symbols=[ZBarSymbol.CODE128])
    if len(barcodes) >= 1:
        return barcodes[0].data.decode('utf-8')
    return None

def resizeBW(img,scale_percent,th):
    src = blackAndWhite(img,th)
    #calculate the 50 percent of original dimensions
    width = int(src.shape[1] * scale_percent / 100)
    height = int(src.shape[0] * scale_percent / 100)

    # dsize
    dsize = (width, height)

    # resize image
    output = cv2.resize(src, dsize)

    cv2.imwrite('frames/dropped/new.jpg',output)
    return cv2.imread('frames/dropped/new.jpg')

#Check for starting marker
def detectMarker(img,count):
    if img is not None:
        data, bbox, straight_qrcode = detector.detectAndDecode(img)
        if bbox is not None:
            if data == "{vidqr}":
                return True
    return False

#compare qr data against previous one
savedVal = ""
def newString(input):
    if input != None:
        global savedVal
        lastVal = savedVal
        savedVal = input
        if input == lastVal:
            return False
        return True
    return None

#get properties from JSON
def getProperties(inputStr):
    #quick check to see if string is actually json
    framerate = 0
    packetsCount = 0
    extension = "txt"
    inputArr = inputStr.split(":")
    fileSize = 1
    for i in range(0,len(inputArr)):
        if i == 0:
            framerate = int(inputArr[0])
        elif i == 1:
            packetsCount = int(inputArr[1])
        elif i == 2:
            extension = inputArr[2]
        elif i == 3:
            fileSize = int(inputArr[3])
    return [framerate,packetsCount,extension,fileSize] #empty json

#Generic implementation of an array buffer
#Saves history up to 'max' values
def addToBuffer(arr,item,max):
    if item is not None:
        arr.append(item)
        if len(arr) > max * 2:
            arr.pop(0)
    return arr

#check if array contains specified item
def checkExists(arr,item):
    for arrItem in arr:
        if arrItem == item:
            return True
    return False

#convert hex string to binary file at path
def binConvertOld(data,path):
    data=data.strip()
    data=data.replace(' ', '')
    data=data.replace('\n', '')
    data = data.split("'")[1]
    data = binascii.a2b_hex(data)
    with open(path, 'wb') as file:
        file.write(data)

#convert hex string to binary file at path
def binConvert(data,path):
    binArr = b''

    for charItem in data:
        binArr += charItem
    with open(path, 'wb') as file:
        file.write(binascii.a2b_base64(binArr))

#fancy-looking percentage bar
def percentageBar(max,value,scale=1):
    if max == 0:
        return ""
    outputString = "["
    percent = round((value / max) * 100)
    ticks = round(percent / scale)
    for index in range(0,round(100 / scale)):
        if index < ticks:
            outputString = outputString + "*"
        else:
            outputString = outputString + " "
    outputString = outputString + "] " + str(percent) + "%"
    return outputString

def shouldRead(skipCount, errorCorrection, itemMissed):
    if skipCount <= 0 or errorCorrection == True or itemMissed == True:
        return True
    return False

def recoverBarcode(image):
    newCode = -1
    print("*** RECOVER BARCODE ***")
    #iterate through each possible threshold until qr code is detected
    for i in range(0,256):
        #Go through only 16 thresholds (132,136,140,...,188)
        #Or, brute-force through 64 thresholds
        if (i % 4 == 0 and i > 64 and i < 192):
            #Attempt to decode image at threshold i
            if readPacketID(image,i) is not -1:
                debug("**** SUCCESSFUL RECOVERY ****")
                return readPacketID(image,i)
    return newCode

def recover(image, droppedArray, interval, fileCount, lastResort):
    recovery = False
    newCode = None
    #Try to beginning of interval, if possible
    startIndex = len(droppedArray) - interval
    if startIndex < 0:
        startIndex = 0
    for index in range(startIndex, len(droppedArray)):
        print("*** RECOVERY MODE ***")
        debug("Attempt: " + str((index - startIndex) + 1) + "/" + str(len(droppedArray) - startIndex))

        #Save original files for reference
        cv2.imwrite("frames/reference_original_" + str(index) + "_" + str(fileCount) + ".jpg", image)
        cv2.imwrite("frames/reference_bw_" + str(index) + "_" + str(fileCount) + ".jpg", blackAndWhite(image))

        if lastResort:
            print("++ Brute-forcing through 256 thresholds ++")
        #iterate through each possible threshold until qr code is detected
        for i in range(0,256):
            #Go through only 16 thresholds (132,136,140,...,188)
            #Or, brute-force through 64 thresholds
            if lastResort or (i % 4 == 0 and i > 64 and i < 192):
                #Attempt to decode image at threshold i
                if readCode(image,i) is not None:
                    debug("**** SUCCESSFUL RECOVERY ****")
                    cv2.imwrite("frames/recovered_" + str(index) + "_" + str(fileCount) + ".jpg", blackAndWhite(image,i))
                    recovery = True
                    return readCode(image,i)

        if recovery == True:
            break

    return newCode

def debug(message):
    if verbose:
        print(message)

def calculateTimeLeft(duration, packets, packetID):
    secsLeft = (duration / packetID) * (packets - packetID)
    secsLeft = secsLeft % (24 * 3600)
    minsLeft = secsLeft // 60
    secsLeft %= 60
    if secsLeft >= 60:
        secsLeft = 59
    return str(round(minsLeft)) + "m " + str(round(secsLeft)) + "s left"

def calculateTimeLeftAdvanced(previousLoadTimes, packetsLeft):
    avgLoadTime = 0
    if len(previousLoadTimes) > 1:
        avgDenominator = 1
        for i in range(0, len(previousLoadTimes)):
            avgLoadTime += previousLoadTimes[i]
            avgDenominator += 1
        avgLoadTime = avgLoadTime / avgDenominator
    secsLeft = avgLoadTime * packetsLeft
    secsLeft = secsLeft % (24 * 3600)
    minsLeft = secsLeft // 60
    secsLeft %= 60
    if secsLeft >= 60:
        secsLeft = 59
    return str(round(minsLeft)) + "m " + str(round(secsLeft)) + "s left"

def calculateRate(duration, packets, packetID, fileSize):
    if duration == 0 or packets == 0 or packetID == 0 or fileSize == 0:
        return "0 Bytes/sec"
    totalSecs = (duration / packetID) * packets
    transferSpeed = round(fileSize / totalSecs)
    if transferSpeed > 1024:
        return str(round(transferSpeed / 1024,1)) + " KB/sec"
    return str(transferSpeed) + " Bytes/sec"

def saveFile(output, properties):
    binConvert(output,args.output)

def decode():
    global output, vidcap

    #Vars used to track status/progress
    count = 0 #tracks current frame
    fileCount = 0 #tracks most recent packetID
    dropped = 0 #tracks number of dropped files
    missCount = 0
    duplicateCount = 0
    recovered = 0

    #Constants
    vidFrameRate = 30 #framerate of video
    packets = 0 #number of packets
    interval = 0 #how many frames should be skipped
    fileSize = 0 #intended file size

    #Indicates file reading stage
    foundMarker = False
    foundProperties = False
    isReading = False

    #Used for recovery and error correction
    errorCorrection = False
    itemMissed = False
    errorCount = 0
    skipCount = 0
    droppedArray = []
    buffer = []
    loadedPackets = []
    finishedCounting = False

    #load initial frame
    vidcap = cv2.VideoCapture(args.path)
    vidFrameRate = vidcap.get(cv2.CAP_PROP_FPS)

    success,image = vidcap.read()


    print("loading...")

    startTime = time.time() #Used to determine time left

    while success and not finishedCounting:
        #print("Frame " + str(count))
        duration = time.time() - startTime #calculate time elasped since starting
        success,image = vidcap.read()
        readCode(resizeBW(image,10,10),10)


        #still waiting for marker and properties
        if isReading == False:
            code = readCode(image)

            #Check if code is the marker if not found already
            if foundMarker == False and code == "{vidqr}":
                debug("found vidqr")

                startTime = time.time() #Now that code has been found, start counting time elapsed
                foundMarker = True
                fileCount += 1
                newString(code) #save code to compare with next frame
            elif foundMarker == True:
                #check if this frame is a new one (not a duplicate)
                if newString(code) == True:
                    if code.startswith("{"):
                        #save json and start streaming the data
                        isReading = True
                        foundProperties = True

                        #Load properties
                        debug("PROPERTIES: " + code)
                        properties = getProperties(code)
                        fileSize = 0
                        packets = properties[1]
                        interval = int(round(vidFrameRate / properties[0]))
                        skipCount = interval
                        fileCount += 1
                        debug("found properties: " + code)
                    else: #code does not appear to be valid json format
                        debug("invalid properties file")
                        debug(code)
                        sys.exit()
        elif fileCount < packets:
            if (skipCount <= 0 or itemMissed or errorCorrection) and image is not None:
                code = readCode(image)
                #Attempt recovery of image
                neededRecovery = False
                if code is None:
                    errorCount += 1 #Keep track to see if it goes over thresh
                    if itemMissed == True:
                        neededRecovery = True
                        if errorCount < interval * 3:
                            code = recover(image, droppedArray, interval, fileCount, False)
                        else:
                            code = recover(image, droppedArray, interval, fileCount, True)
                        if code is None and checkExists(loadedPackets,fileCount + 1) == False:
                            print("ERROR: PACKET DROPPED")
                            dropped += 1

                    if errorCount == interval:
                        itemMissed = True


                if code is not None:
                    if neededRecovery:
                        recovered += 1
                    #RECIEVED VALID DATA: PROCESS NOW
                    skipCount = interval
                    if code != "{vidqr}" and not code.startswith("{"):
                        packetID = int(code.split(":")[0])

                        loaded = True

                        if packetID == fileCount + 1: #packetID is correct
                            if checkExists(loadedPackets, packetID):
                                debug("***** PACKET ALREADY LOADED: SHOULDN'T BE ADDED *****")
                            else:
                                #CONSOLE OUTPUT
                                debug("LOADED: packet " + str(packetID))
                                print("\033c")
                                print(percentageBar(packets,packetID))
                                print(calculateTimeLeft(duration,packets,packetID))
                                print(calculateRate(duration,packets,packetID,fileSize))
                                #MODIFY DATA
                                output = output + code.split(':',maxsplit=1)[1]
                                loadedPackets.append(packetID)
                                itemMissed = False
                                errorCount = 0
                                droppedArray = []
                                fileCount = packetID
                        elif checkExists(loadedPackets, fileCount + 1) == False and not checkExists(loadedPackets, packetID): #packetID is higher than expected; one may have been skipped
                            debug("MISSED: packet " + str(fileCount + 1) + " " + str(packetID) + " instead of " + str(fileCount + 1))
                            itemMissed = True
                            #Rewind stream and step through until packet is recovered
                            count = count - (interval * 2)
                            vidcap.set(1,count)
                            packetID -= 1
                            missCount += 1
                        elif checkExists(loadedPackets, packetID):
                            debug("DUPLICATE: packet " + str(packetID))
                            duplicateCount += 1
                        if len(loadedPackets) + 2 >= packets:
                            finishedCounting = True

        if skipCount > 0:
            skipCount -= 1
        buffer = addToBuffer(buffer, count, interval)
        count += 1
        droppedArray.append(image) #keep a copy of this frame in buffer for recovery purposes

    print("\nSaved file to " + args.output + "\n")
    print("STATISTICS")
    print("--------------------")
    print("Duplicates: " + str(duplicateCount))
    print("Recovered:  " + str(recovered))
    print("Dropped:    " + str(dropped))
    print("Missed:     " + str(missCount) + "\n")

    totalSecs = duration
    transferSpeed = round(fileSize / totalSecs)
    print("Duration: " + str(round(totalSecs,1)) + " seconds")
    print("Rate: " + str(transferSpeed) + " Bytes/sec")

    saveFile(properties)

    actualSize = os.path.getsize(args.output)
    if fileSize != actualSize:
        print("NOTE: File size mismatch")
        print("Intended: " + str(fileSize) + " Bytes")
        print("Actual:   " + str(actualSize) + " Bytes")

def decodeBC():
    global output, vidcap

    #Vars used to track status/progress
    count = 0 #tracks current frame
    fileCount = 0 #tracks most recent packetID
    dropped = 0 #tracks number of dropped files
    missCount = 0
    duplicateCount = 0
    recovered = 0

    #Constants
    vidFrameRate = 30 #framerate of video
    packets = 0 #number of packets
    interval = 0 #how many frames should be skipped
    fileSize = 1 #intended file size

    finishedCounting = False
    foundBarcode = False
    startedCounting = False

    #Used for recovery and error correction
    errorCorrection = False
    itemMissed = False
    errorCount = 0
    skipCount = 0
    droppedArray = []
    buffer = []
    loadedPackets = []
    sortedPackets = []

    previousLoadTimes = []


    #load initial frame
    vidcap = cv2.VideoCapture(args.path)
    vidFrameRate = vidcap.get(cv2.CAP_PROP_FPS)

    success,image = vidcap.read()

    barcode = readBarcode(image)
    if barcode is not None:
        foundBarcode = True
        properties = getProperties(barcode)
        packets = properties[1]
        fileSize = properties[3]
        for packet in range(0, packets):
            sortedPackets.append(b'')
        interval = int(round(vidFrameRate / float(properties[0])))

    print("loading...")

    startTime = time.time() #Used to determine time left
    previousLoad = time.time()

    while success and not finishedCounting:
        duration = time.time() - startTime #calculate time elasped since starting
        success,image = vidcap.read()

        print("\033c")
        print(percentageBar(packets,len(loadedPackets) + 1))
        print(calculateTimeLeftAdvanced(previousLoadTimes,packets - (len(loadedPackets) + 1)))
        print(calculateRate(duration,packets,len(loadedPackets) + 1,fileSize))
        print("Last loaded: " + str(fileCount))
        print("Frame: " + str(count))


        if foundBarcode == False:
            barcode = readBarcode(image)
            if barcode is not None:
                foundBarcode = True
                properties = getProperties(barcode)
                packets = properties[1]
                fileSize = properties[3]
                for packet in range(0, packets):
                    sortedPackets.append(b'')
                interval = int(round(vidFrameRate / float(properties[0])))

        elif len(loadedPackets) <= packets:
            if fileCount == packets:
                fileCount = 0
            if (skipCount <= 0 or itemMissed or errorCorrection) and image is not None:
                code = readCode(image)
                #Attempt recovery of image
                neededRecovery = False
                if code is None and len(loadedPackets) > 0:
                    errorCount += 1 #Keep track to see if it goes over thresh
                    if itemMissed == True:
                        neededRecovery = True
                        code = recover(image, droppedArray, interval, fileCount, False)
                        if code is None:
                            count = count - 4
                            vidcap.set(1,count)

                    if errorCount == interval:
                        itemMissed = True
                if code is not None:
                    packetID = readPacketID(image,128)
                    if packetID == -1:
                        packetID = recoverBarcode(image)

                    print(packetID)
                    if neededRecovery:
                        recovered += 1
                    #RECIEVED VALID DATA: PROCESS NOW
                    skipCount = interval


                    if not startedCounting:
                        fileCount = packetID - 1
                        startedCounting = True

                    loaded = True

                    if not checkExists(loadedPackets, packetID) and packetID == fileCount + 1: #packetID is correct
                        #CONSOLE OUTPUT
                        debug("LOADED: packet " + str(packetID))
                        previousLoadTimes = addToBuffer(previousLoadTimes, time.time() - previousLoad, 100)
                        previousLoad = time.time()

                        #MODIFY DATA
                        loadedPackets.append(packetID)
                        sortedPackets[packetID - 1] = code
                        itemMissed = False
                        errorCorrection = False
                        errorCount = 0
                        droppedArray = []
                        fileCount = packetID
                    elif checkExists(loadedPackets, fileCount + 1) == False and not checkExists(loadedPackets, packetID):
                        debug("MISSED: packet " + str(fileCount + 1) + " - " + str(packetID) + " - " + str(count))
                        if not itemMissed:
                            itemMissed = True
                            packetID -= 1
                            missCount += 1
                        else:
                            count = count - 4
                            vidcap.set(1,count)

                    else:
                        debug("DUPLICATE: packet " + str(packetID))
                        errorCorrection = True
                        duplicateCount += 1
                    if len(loadedPackets) >= packets:
                        finishedCounting = True

        if skipCount > 0:
            skipCount -= 1
        buffer = addToBuffer(buffer, count, interval)
        count += 1
        droppedArray.append(image) #keep a copy of this frame in buffer for recovery purposes

    print("\nSaved file to " + args.output + "\n")
    print("STATISTICS")
    print("--------------------")
    print("Duplicates: " + str(duplicateCount))
    print("Recovered:  " + str(recovered))
    print("Dropped:    " + str(dropped))
    print("Missed:     " + str(missCount) + "\n")

    totalSecs = duration
    transferSpeed = round(fileSize / totalSecs)
    print("Duration: " + str(round(totalSecs,1)) + " seconds")
    print("Rate: " + str(transferSpeed) + " Bytes/sec")

    #print(sortedPackets)
    saveFile(sortedPackets, properties[2])

    actualSize = os.path.getsize(args.output)
    if fileSize != actualSize:
        print("NOTE: File size mismatch")
        print("Intended: " + str(fileSize) + " Bytes")
        print("Actual:   " + str(actualSize) + " Bytes")

decodeBC()
