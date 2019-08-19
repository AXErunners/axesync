#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

struct BitPayRates: Codable {
    let items: [BitPayRate]
    
    enum CodingKeys: String, CodingKey {
        case items = "data"
    }
}

struct BitPayRate: Codable {
    let code: String
    let name: String
}

struct AxeRetailRate: Codable {
    let symbol: String
    let code: String
    
    enum CodingKeys: String, CodingKey {
        case symbol = "symbol"
        case code = "quoteCurrency"
    }
}

////////////////////////////////////////////////////////

print("Working...")

let skipCurrencies = ["BTC", "BCH", "XAG", "XAU", "VEF", "ETH", "LTC", "AXE", "USDC", "PAX", "GUSD"]

// Bitpay

let bitpayRatesData = try! Data(contentsOf: URL(string: "https://bitpay.com/rates")!)
let bitPayRates = try! JSONDecoder().decode(BitPayRates.self, from: bitpayRatesData)
let bitPayItems = bitPayRates.items.filter { !skipCurrencies.contains($0.code) }
let currenciesBitPay = bitPayItems.map { $0.code }.sorted()
print("\n\nBitPay:", currenciesBitPay)

// Spark

let sparkRatesData = try! Data(contentsOf: URL(string: "https://axerunners.com/list")!)
let sparkRates: [String:Any] = try! JSONSerialization.jsonObject(with: sparkRatesData, options: .init(rawValue: 0)) as! [String:Any]
let currenciesSpark = sparkRates.keys.sorted()
print("\n\nSpark:", currenciesSpark)

// AxeRetail

let axeretailRatesData = try! Data(contentsOf: URL(string: "https://rates2.axeretail.org/rates?source=axeretail")!)
let axeretailRates = try! JSONDecoder().decode(Array<AxeRetailRate>.self, from: axeretailRatesData)
let currenciesAxeRetail = axeretailRates.filter {$0.symbol.hasPrefix("AXE") && !skipCurrencies.contains($0.code)}.map { $0.code }.sorted()
print("\n\nAxeRetail:", currenciesAxeRetail)

let notInSpark = currenciesBitPay.filter { !currenciesSpark.contains($0) }
let notInBitPayButInSpark = currenciesSpark.filter { !currenciesBitPay.contains($0) }
let notInAxeRetail = currenciesAxeRetail.filter { !currenciesSpark.contains($0) }
let notInBitPayButInAxeRetail = currenciesSpark.filter { !currenciesAxeRetail.contains($0) }

print("\n\nNot in Spark but in BitPay:", notInSpark.count, notInSpark)
print("Not in BitPay but in Spark:", notInBitPayButInSpark.count, notInBitPayButInSpark)
print("Not in BitPay but in AxeRetail:", notInAxeRetail.count, notInAxeRetail)
print("Not in AxeRetail but in BitPay:", notInBitPayButInAxeRetail.count, notInBitPayButInAxeRetail)

var currencyNamesByCode: [String: String] = [:]
for item in bitPayItems {
    currencyNamesByCode[item.code] = item.name
}

let path = FileManager.default.currentDirectoryPath
let filePath: String
let bundleId = Bundle.main.bundleIdentifier ?? ""
if bundleId.hasPrefix("com.apple.dt") {
    // In playground
    filePath = "CurrenciesByCode.plist"
}
else {
    filePath = "../AxeSync/CurrenciesByCode.plist"
}
let url = URL(fileURLWithPath: path).appendingPathComponent(filePath)
let encoder = PropertyListEncoder()
encoder.outputFormat = .xml
let data = try encoder.encode(currencyNamesByCode)
try! data.write(to: url)

print("Exported to: ")
print(url.path)
