//
//  MameXmlParser.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

nonisolated final class MameXmlParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private var games: [String: Game] = [:]

    // Parsing state
    private var currentElement: String = ""
    private var currentText: String = ""

    private var isInsideMachine: Bool = false
    private var isDevice: Bool = false
    private var machineName: String = ""
    private var sourceFile: String = ""
    private var cloneOf: String?
    private var romOf: String?

    private var descriptionText: String = ""
    private var yearText: String = ""
    private var manufacturerText: String = ""
    private var driverStatusText: String = ""
    private var controlsText: String = ""
    private var hasRoms: Bool = false
    private var hasChd: Bool = false
    private var chdName: String?

    func parse(data: Data) -> [String: Game] {
        games.removeAll()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.parse()
        return games
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""

        if elementName == "machine" {
            isInsideMachine = true
            isDevice = (attributeDict["isdevice"] == "yes")
            machineName = attributeDict["name"] ?? ""
            sourceFile = attributeDict["sourcefile"] ?? ""
            cloneOf = attributeDict["cloneof"]
            romOf = attributeDict["romof"]

            descriptionText = ""
            yearText = ""
            manufacturerText = ""
            driverStatusText = "good"
            controlsText = ""
            hasRoms = false
            hasChd = false
            chdName = nil
        } else if isInsideMachine {
            if elementName == "rom" {
                hasRoms = true
            } else if elementName == "disk" {
                hasChd = true
                if chdName == nil {
                    chdName = attributeDict["name"]
                }
            } else if elementName == "driver" {
                driverStatusText = attributeDict["status"] ?? "good"
            } else if elementName == "control" {
                if controlsText.isEmpty {
                    let type = attributeDict["type"] ?? ""
                    if let ways = attributeDict["ways"] {
                        controlsText = "\(type) (\(ways)-way)"
                    } else {
                        controlsText = type
                    }
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if isInsideMachine {
            switch elementName {
            case "description":
                descriptionText = trimmed
            case "year":
                yearText = trimmed
            case "manufacturer":
                manufacturerText = trimmed
            case "machine":
                if !isDevice && !machineName.isEmpty {
                    let parent = cloneOf ?? romOf
                    let isClone = (cloneOf != nil)

                    let game = Game(
                        name: machineName,
                        description: descriptionText.isEmpty ? machineName : descriptionText,
                        manufacturer: manufacturerText,
                        year: yearText,
                        driver: sourceFile,
                        driverStatus: driverStatusText,
                        status: .available,
                        parent: parent,
                        category: "",
                        playCount: 0,
                        isClone: isClone,
                        controls: controlsText,
                        requiresRoms: hasRoms,
                        requiresChd: hasChd,
                        chdName: chdName,
                        verificationStatus: .notVerified
                    )
                    games[machineName.lowercased()] = game
                }
                isInsideMachine = false
            default:
                break
            }
        }
    }
}
