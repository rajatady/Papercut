//
//  ArXivXMLParser.swift
//  Papercut
//

import Foundation

final class ArXivXMLParser: NSObject {
    private var papers: [ParsedPaper] = []
    private var currentPaper: ParsedPaper?
    private var currentElement: String = ""
    private var currentText: String = ""
    private var currentAuthor: ParsedAuthor?
    private var currentLink: (href: String, title: String?, type: String?)?
    private var totalResults: Int = 0

    struct ParsedPaper {
        var id: String = ""
        var title: String = ""
        var abstract: String = ""
        var authors: [ParsedAuthor] = []
        var categories: [String] = []
        var published: Date?
        var updated: Date?
        var pdfURL: String = ""
        var abstractURL: String = ""
    }

    struct ParsedAuthor {
        var name: String = ""
        var affiliation: String?
    }

    struct ParseResult {
        let papers: [ParsedPaper]
        let totalResults: Int
    }

    func parse(data: Data) throws -> ParseResult {
        papers = []
        totalResults = 0

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true

        guard parser.parse() else {
            throw ArXivParserError.parsingFailed(parser.parserError)
        }

        return ParseResult(papers: papers, totalResults: totalResults)
    }
}

// MARK: - XMLParserDelegate
extension ArXivXMLParser: XMLParserDelegate {
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "entry":
            currentPaper = ParsedPaper()

        case "author":
            currentAuthor = ParsedAuthor()

        case "link":
            let href = attributeDict["href"] ?? ""
            let title = attributeDict["title"]
            let type = attributeDict["type"]
            currentLink = (href, title, type)

            // Process link immediately
            if let paper = currentPaper {
                if title == "pdf" {
                    currentPaper?.pdfURL = href
                } else if type == "text/html" || (title == nil && type == nil && href.contains("abs")) {
                    currentPaper?.abstractURL = href
                }
            }

        case "category":
            if let term = attributeDict["term"], currentPaper != nil {
                currentPaper?.categories.append(term)
            }

        default:
            break
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
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "entry":
            if let paper = currentPaper {
                papers.append(paper)
            }
            currentPaper = nil

        case "id":
            if currentPaper != nil {
                currentPaper?.id = trimmedText
                // If we don't have an abstract URL yet, derive it from the ID
                if currentPaper?.abstractURL.isEmpty == true {
                    currentPaper?.abstractURL = trimmedText
                }
            }

        case "title":
            if currentPaper != nil {
                // Clean up title - remove newlines and extra spaces
                let cleanTitle = trimmedText
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                currentPaper?.title = cleanTitle
            }

        case "summary":
            if currentPaper != nil {
                // Clean up abstract
                let cleanAbstract = trimmedText
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                currentPaper?.abstract = cleanAbstract
            }

        case "published":
            if currentPaper != nil {
                currentPaper?.published = parseDate(trimmedText)
            }

        case "updated":
            if currentPaper != nil {
                currentPaper?.updated = parseDate(trimmedText)
            }

        case "name":
            if currentAuthor != nil {
                currentAuthor?.name = trimmedText
            }

        case "affiliation":
            if currentAuthor != nil {
                currentAuthor?.affiliation = trimmedText
            }

        case "author":
            if let author = currentAuthor, currentPaper != nil {
                currentPaper?.authors.append(author)
            }
            currentAuthor = nil

        case "totalResults":
            // opensearch:totalResults
            totalResults = Int(trimmedText) ?? 0

        default:
            break
        }

        currentText = ""
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}

// MARK: - Errors
enum ArXivParserError: Error, LocalizedError {
    case parsingFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .parsingFailed(let underlyingError):
            if let error = underlyingError {
                return "Failed to parse ArXiv response: \(error.localizedDescription)"
            }
            return "Failed to parse ArXiv response"
        }
    }
}

// MARK: - Conversion to Domain Models
extension ArXivXMLParser.ParsedPaper {
    func toPaper() -> Paper {
        let authors = self.authors.map { Author(name: $0.name, affiliation: $0.affiliation) }

        return Paper(
            id: id,
            title: title,
            abstract: abstract,
            authors: authors,
            categories: categories,
            publishedDate: published ?? Date(),
            updatedDate: updated ?? Date(),
            pdfURL: pdfURL,
            abstractURL: abstractURL
        )
    }
}
