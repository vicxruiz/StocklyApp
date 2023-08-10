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
    @Environment(\.isSearching) private var isSearching
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.content.isEmpty {
                    VStack(spacing: 8) {
                        Text("Search Stocks")
                            .font(.headline)
                        Text("Add symbols to your watch list")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .offset(y: -40)
                } else {
                    List {
                        Section("My Symbols") {
                            ForEach(viewModel.content.indices, id: \.self) { index in
                                NavigationLink {
                                    Text("\(index)")
                                } label: {
                                    StockCell(index: index, viewModel: viewModel)
                                }

                            }
                        }
                    }
                }
            }
            .searchable(text: $viewModel.query)
            .task {
                guard !hasAppeared else { return }
                hasAppeared = true
                viewModel.trigger(.fetchStocks)
            }
            .navigationTitle("Stocks")
        }
    }
}

struct StockCell: View {
    let index: Int
    @ObservedObject var viewModel: ContentViewModel
    var body: some View {
        HStack {
            Button {
                viewModel.content[index].isStored.toggle()
            } label: {
                if viewModel.content[index].isStored {
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
                    Text("AAPL")
                        .fontWeight(.bold)
                    Text("NYSE")
                        .foregroundColor(Color(uiColor: .darkGray))
                        .font(.footnote)
                        .fontWeight(.semibold)
                    Text("USD")
                        .foregroundColor(Color(uiColor: .darkGray))
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
                Text("Apple Inc.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
    }
}

final class ContentViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            print(query)
        }
    }
    @Published var content: [Content] = []
    
    enum Input {
        case fetchStocks
    }
    
    let repository: StockRepository
    
    init(repository: StockRepository) {
        self.repository = repository
    }
    
    func trigger(_ input: Input) {
        switch input {
        case .fetchStocks: fetchStocks()
        }
    }
    
    private func fetchStocks() {
        
    }
}

enum StockError: Error {
    case invalidURL
}

protocol StockRepository {
    func fetchStocks(completion: @escaping (Result<[Content], Error>)->Void)
    func query(for symbol: String, completion: @escaping (Result<[SearchResponse], Error>)->Void)
}

final class StockService: StockRepository {
    let baseURL = "https://api.twelvedata.com"
    
    enum QueryItem: String {
        case search = "search_symbol"
    }
    
    func query(for symbol: String, completion: @escaping (Result<[SearchResponse], Error>) -> Void) {
        var components = URLComponents(string: baseURL)
        let searchQueryItem = URLQueryItem(name: QueryItem.search.rawValue, value: symbol)
        
        components?.queryItems = [searchQueryItem]
        
        guard let url = components?.url else {
            completion(.failure(StockError.invalidURL))
            return
        }
        
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
    
    func fetchStocks(completion: @escaping (Result<[Content], Error>) -> Void) {
        print("fetched")
        var result: [Content] = []
        for index in 1...30 {
            result.append(.init(name: "Test: \(index)", value: index, isStored: false))
        }
        completion(.success(result))
    }
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

struct ContentPreview_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
