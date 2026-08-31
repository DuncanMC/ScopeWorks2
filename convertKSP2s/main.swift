//
//  main.swift
//  convertKSP2s
//
//  Created by Duncan Champney on 8/31/26.
//

import Foundation

let sourceDirPath = "/Users/duncan/Desktop/Development/ScopeWorks2/ScopeWorks2/Shared/ScopeWorks Documents"
let destinationDirPath = "/Users/duncan/Desktop/Development/ScopeWorks2/ScopeWorks2/Shared/ScopeWorks Documents (kspp)"

let fileManager = FileManager.default


func turnDirectoryIntoPackage(at directoryURL: URL) {
    do {
        var resourceValues = URLResourceValues()
        resourceValues.isPackage = true

        var mutableURL = directoryURL // Mark the directory as a file package
        try mutableURL.setResourceValues(resourceValues)
        print("Successfully turned directory into a file package.")
    } catch {
        print("Failed to set package flag: \(error.localizedDescription)")
    }
}


do {
    
    let fileURLs = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: sourceDirPath), includingPropertiesForKeys: nil, options: [])
    
    let destinationDirURL = URL(fileURLWithPath: destinationDirPath)
    
    for fileURL in fileURLs {
        let filename = fileURL.lastPathComponent
        print("Processing file \"\(filename)\"")
        let filenameParts = filename.split(separator: ".")
        if filenameParts.count != 2 {
            print("Filename \(filename) does not have 2 parts. Skipping.")
            continue
        }
        let filenameWithoutExtension = filenameParts[0]
        let fileExtension = filenameParts[1]
        if fileExtension != "ksp2" { continue }
        //Create directory with filename "filename.kspp" in destinationURL
        let newDocumentName = "\(filenameWithoutExtension).kspp"
        let newDocumentURL = destinationDirURL.appending(component: newDocumentName, directoryHint: .isDirectory)
        let dataURL = newDocumentURL.appending(component: "document.json", directoryHint: .notDirectory)
        if fileManager.fileExists(atPath: newDocumentURL.path) {
            print("File already exists. Skipping.")
            continue
        }
        try fileManager.createDirectory(at: newDocumentURL, withIntermediateDirectories: false)
        //copy filename.ksp2 to "document.json" in new directory
        try FileManager.default.copyItem(at: fileURL, to: dataURL)

//        turnDirectoryIntoPackage(at: newDocumentURL)
        //set package flag on new directory "filename.kspp"
        
    }
} catch { 
    print("Error \(error.localizedDescription)")
}



