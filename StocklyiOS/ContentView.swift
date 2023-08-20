//
//  ContentView.swift
//  StocklyiOS
//
//  Created by Victor Ruiz on 7/20/23.
//

import SwiftUI

struct Content: Identifiable, Hashable, Codable {
    var id = UUID()
    let name: String
    let value: Int
    var isStored: Bool
}

struct ContentView: View {
    @State private var hasAppeared = false
    @ObservedObject var viewModel = ContentViewModel(repository: StockService())
    @State var addSymbolPressed: Bool = false
    @Environment(\.isSearching) private var isSearching: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.watchList.isEmpty, viewModel.content.isEmpty {
                    VStack(spacing: 8) {
                        Text("Search Stocks")
                            .font(.headline)
                        Text("Add symbols to your watch list")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .offset(y: -40)
                } else if !viewModel.content.isEmpty {
                    List {
                        Section("Search") {
                            ForEach(viewModel.content.indices, id: \.self) { index in
                                NavigationLink {
                                    Text("\(index)")
                                } label: {
                                    StockCell(index: index, viewModel: viewModel)
                                }
                            }
                        }
                    }
                } else if let watchList = viewModel.watchList, !watchList.isEmpty {
                    List {
                        Section("Watch List") {
                            ForEach(viewModel.watchList.indices, id: \.self) { index in
                                NavigationLink {
                                    Text("\(index)")
                                } label: {
                                    WatchListCell(index: index, viewModel: viewModel)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $viewModel.query)
            .onChange(of: viewModel.query) { value in
                if value.isEmpty && !isSearching {
                    viewModel.clear()
                }
            }
            .task {
                guard !hasAppeared else { return }
                hasAppeared = true
            }
            .navigationTitle("Stocks")
        }
    }
}

struct WatchListCell: View {
    let index: Int
    @ObservedObject var viewModel: ContentViewModel
    var body: some View {
        if !viewModel.watchList.isEmpty {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(viewModel.watchList[index])
                            .fontWeight(.bold)
                            .scaledToFit()
                    }
                }
            }
        }
    }
}


struct StockCell: View {
    let index: Int
    @ObservedObject var viewModel: ContentViewModel
    var body: some View {
        if !viewModel.content.isEmpty {
            HStack {
                Button {
                    let symbol = viewModel.content[index].symbol
                    viewModel.trigger(.addToWatchList(symbol))
                } label: {
                    if viewModel.isInWatchList(viewModel.content[index].symbol) {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(Color.teal)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(viewModel.content[index].symbol)
                            .fontWeight(.bold)
                            .scaledToFit()
                        Text(viewModel.content[index].exchange)
                            .foregroundColor(Color(uiColor: .darkGray))
                            .font(.footnote)
                            .fontWeight(.semibold)
                        Text(viewModel.content[index].currency)
                            .foregroundColor(Color(uiColor: .darkGray))
                            .font(.footnote)
                            .fontWeight(.semibold)
                    }
                    if !viewModel.content[index].name.isEmpty {
                        Text(viewModel.content[index].name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("$127.19")
                        .fontWeight(.semibold)
                    Text("+2.95")
                        .fontWeight(.semibold)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .foregroundStyle(Color.green)
                        .background {
                            Color.green.opacity(0.15)
                        }
                        .cornerRadius(6)
                }
            }
            .task {
                if !viewModel.content.isEmpty {
                    await viewModel.task(.fetchPrice(viewModel.content[index].symbol))
                }
            }
        }
    }
}

final class ContentViewModel: NSObject, ObservableObject {
    @Published var query: String = "" {
        didSet {
            NSObject.cancelPreviousPerformRequests(
                withTarget: self,
                selector: #selector(querySymbol),
                object: self
            )
            
            guard !query.isEmpty else {
                return
            }
            
            self.perform(#selector(querySymbol), with: nil, afterDelay: 0.5)
        }
    }
    @Published var content: [SearchResponse] = []
    @Published var watchList = UserDefaults.watchList
    
    enum Input {
        case fetchStocks
        case clear
        case addToWatchList(String)
    }
    
    enum Task {
        case fetchPrice(String)
    }
    
    let repository: StockRepository
    
    init(repository: StockRepository) {
        self.repository = repository
    }
    
    func task(_ task: Task) async {
        switch task {
            case .fetchPrice(let symbol): await fetchStockPrice(for: symbol)
        }
    }
    
    func trigger(_ input: Input) {
        switch input {
        case .fetchStocks: fetchStocks()
        case .clear: clear()
        case .addToWatchList(let symbol): addToWatchList(symbol)
        }
    }
    
    @objc private func querySymbol() {
        repository.query(for: query) { result in
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    self.content = response
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    private func fetchStockPrice(for symbol: String) async {
        let response = await repository.fetchStockPrice(for: symbol)
        switch response {
        case .success(let success):
            print(success)
        case .failure(let failure):
            print(failure)
        }
    }
    
    private func fetchStocks() {
        
    }
    
    private func addToWatchList(_ symbol: String) {
        UserDefaults.addToWatchList(symbol)
    }
    
    func clear() {
        content.removeAll()
    }
    
    func isInWatchList(_ symbol: String) -> Bool {
        return watchList.contains(symbol)
    }
}

enum StockError: Error {
    case invalidURL
}

protocol StockRepository {
    func fetchStocks(completion: @escaping (Result<[Content], Error>)->Void)
    func query(for symbol: String, completion: @escaping (Result<[SearchResponse], Error>)->Void)
    func fetchStockPrice(for symbol: String) async -> Result<(String, String), Error>
}

final class StockService: StockRepository {
    let baseURL = "https://api.twelvedata.com"
    let apiKey = "017d616c69e24cb382a98257702a34a0"
    
    enum QueryItem: String {
        case symbol = "symbol"
        case apiKey = "apikey"
    }
    
    enum Path: String {
        case search = "symbol_search"
        case price = "price"
        case quote = "quote"
    }
    
    func query(for symbol: String, completion: @escaping (Result<[SearchResponse], Error>) -> Void) {
        var components = URLComponents(string: baseURL)
        let symbolQueryItem = URLQueryItem(name: QueryItem.symbol.rawValue, value: symbol)
        
        components?.queryItems = [symbolQueryItem]
        
        guard var url = components?.url else {
            completion(.failure(StockError.invalidURL))
            return
        }
        url.append(path: Path.search.rawValue)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(SearchRootRespose.self, from: data)
                    completion(.success(response.data))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    func fetchStockPrice(for symbol: String) async -> Result<(String, String), Error> {
        do {
            let change = try await fetchChange(for: symbol)
            let realTimePrice = try await fetchRealTimePrice(for: symbol)
            
            // Update your UI with the fetched data
            print("Historical Change: \(change)")
            print("Real-Time Price: \(realTimePrice)")
            
            // Update your UI components with the fetched data
            return .success((change, realTimePrice))
        } catch {
            print("Error: \(error)")
            return .failure(error)
        }
    }
    
    // Fetch historical data
    private func fetchChange(for symbol: String) async throws -> String {
        var components = URLComponents(string: baseURL)
        let symbolQueryItem = URLQueryItem(name: QueryItem.symbol.rawValue, value: symbol)
        let apiQueryItem = URLQueryItem(name: QueryItem.apiKey.rawValue, value: apiKey)
        
        components?.queryItems = [symbolQueryItem, apiQueryItem]
        
        guard var url = components?.url else {
            throw StockError.invalidURL
        }
        url.append(path: Path.quote.rawValue)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let stockData = try decoder.decode(QuoteResponse.self, from: data)
        return stockData.change ?? "0"
    }

    // Fetch real-time price
    private func fetchRealTimePrice(for symbol: String) async throws -> String {
        var components = URLComponents(string: baseURL)
        let symbolQueryItem = URLQueryItem(name: QueryItem.symbol.rawValue, value: symbol)
        let apiQueryItem = URLQueryItem(name: QueryItem.apiKey.rawValue, value: apiKey)
        
        components?.queryItems = [symbolQueryItem, apiQueryItem]
        
        guard var url = components?.url else {
            throw StockError.invalidURL
        }
        url.append(path: Path.price.rawValue)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print(url)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let stockData = try decoder.decode(PriceResponse.self, from: data)
        return stockData.price
    }
    
    func fetchStocks(completion: @escaping (Result<[Content], Error>) -> Void) {
        print("fetched")
        var result: [Content] = []
        for index in 1...30 {
            result.append(.init(name: "Test: \(index)", value: index, isStored: false))
        }
        completion(.success(result))
    }
}

struct QuoteResponse: Codable {
    let change: String?
}

struct PriceResponse: Codable {
    let price: String
}

struct SearchRootRespose: Codable {
    let data: [SearchResponse]
}

struct SearchResponse: Codable {
    let symbol: String
    let exchange: String
    let currency: String
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case symbol
        case exchange
        case currency
        case name = "instrument_name"
    }
}
/*
"symbol": "AA",
      "instrument_name": "Alcoa Corp",
      "exchange": "NYSE",
      "mic_code": "XNYS",
      "exchange_timezone": "America/New_York",
      "instrument_type": "Common Stock",
      "country": "United States",
      "currency": "USD"
 
 */

extension UserDefaults {
    enum Keys: String {
        case watchList
    }
    static var watchList: [String] = {
        let list = UserDefaults.standard.array(forKey: Keys.watchList.rawValue) as? [String]
        if let list, !list.isEmpty {
            return list
        } else {
            return []
        }
    }()
    
    static func addToWatchList(_ value: String) {
        let list = UserDefaults.standard.array(forKey: Keys.watchList.rawValue) as? [String]
        if var list, !list.isEmpty {
            list.append(value)
            UserDefaults.standard.set(list, forKey: Keys.watchList.rawValue)
        } else {
            let newList = [value]
            UserDefaults.standard.set(newList, forKey: Keys.watchList.rawValue)
        }
    }
}

struct ContentPreview_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
