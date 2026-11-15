@testable import Eathat
import Foundation
import Testing

@Suite("API kitchen service")
struct APIKitchenServiceTests {
    private let lineJSON = """
    {"id":27,"productId":27,"name":"Baguette","brand":null,"category":"pain","tags":"gluten","quantity":4,
    "initialQuantity":4,"unit":"baguette","location":"placard","bestBefore":"2026-11-15","bestBeforeIsEstimate":true,
    "daysLeft":1,"openedAt":null,"frozenAt":null,"status":"dispo",
    "imageUrl":"https://www.themealdb.com/images/ingredients/Baguette-Small.png"}
    """

    @Test("reads the stock from GET /v1/stock")
    func stock() async throws {
        let client = FakeHTTPClient(answer: #"{"today":"2026-11-14","items":[\#(lineJSON)]}"#)
        let lines = try await APIKitchenService(client: client).stock()
        #expect(lines.map(\.name) == ["Baguette"])
        #expect(lines.first?.location == .placard)
        #expect(lines.first?.daysLeft == 1)
        #expect(lines.first?.imageUrl?.lastPathComponent == "Baguette-Small.png")
        #expect(await client.requests == [.get("v1/stock")])
    }

    @Test("sends a quick action to its own path, with its payload")
    func perform() async throws {
        let client = FakeHTTPClient(answer: lineJSON)
        let line = try await APIKitchenService(client: client).perform(.move(.congelateur), on: 27)
        #expect(line.id == 27)
        let request = try #require(await client.requests.first)
        #expect(request.method == "POST")
        #expect(request.path == "v1/stock/27/move")
        let body = try JSONDecoder().decode([String: String].self, from: try #require(request.body))
        #expect(body == ["location": "congelateur"])
    }

    @Test("reads recipes and cooks one")
    func recipes() async throws {
        let recipe = """
        {"id":1,"title":"Pâtes","servings":2,"prepMinutes":null,"steps":"1. Cuire","tags":[],"rating":null,"notes":null,
        "createdAt":"2026-11-14T18:00:00Z","updatedAt":"2026-11-14T18:00:00Z","imageUrl":null,
        "ingredients":[{"name":"penne","productId":13,"quantity":250,"unit":"g","quantityText":null,"optional":false}]}
        """
        let recipesClient = FakeHTTPClient(answer: #"{"recipes":[\#(recipe)]}"#)
        let recipes = try await APIKitchenService(client: recipesClient).recipes()
        #expect(recipes.first?.ingredients.first?.productId == 13)
        #expect(recipes.first?.imageUrl == nil)

        let meal = #"{"mealId":3,"recipeId":1,"taken":[],"skipped":[{"name":"sel","reason":"pas lié au stock"}]}"#
        let client = FakeHTTPClient(answer: meal)
        let cooked = try await APIKitchenService(client: client).cook(recipeId: 1)
        #expect(cooked.skipped.map(\.name) == ["sel"])
        #expect(await client.requests == [.post("v1/recipes/1/cooked")])
    }

    @Test("reads the plan, adds a meal, takes one off")
    func plan() async throws {
        let meal = """
        {"id":4,"day":"2026-11-16","slot":"soir","recipeId":2,"title":"Ratatouille express",
        "imageUrl":"https://www.themealdb.com/images/media/meals/wrpwuu1511786491.jpg","prepMinutes":35}
        """
        let planClient = FakeHTTPClient(answer: #"{"today":"2026-11-15","meals":[\#(meal)]}"#)
        let meals = try await APIKitchenService(client: planClient).plan()
        #expect(meals.map(\.slot) == [.soir])
        #expect(meals.first?.imageUrl?.lastPathComponent == "wrpwuu1511786491.jpg")
        #expect(await planClient.requests == [.get("v1/plan")])

        let addClient = FakeHTTPClient(answer: meal)
        _ = try await APIKitchenService(client: addClient).addToPlan(day: "2026-11-16", slot: .midi, recipeId: 2)
        let request = try #require(await addClient.requests.first)
        #expect(request.path == "v1/plan")
        let body = try JSONSerialization.jsonObject(with: try #require(request.body)) as? [String: Any]
        #expect(body?["day"] as? String == "2026-11-16")
        #expect(body?["slot"] as? String == "midi")
        #expect(body?["recipeId"] as? Int == 2)

        let removeClient = FakeHTTPClient(answer: #"{"id":4,"removed":true}"#)
        try await APIKitchenService(client: removeClient).removeFromPlan(id: 4)
        #expect(await removeClient.requests == [.delete("v1/plan/4")])
    }

    @Test("reads the preferences from GET /v1/preferences")
    func preferences() async throws {
        let client = FakeHTTPClient(answer: #"{"preferences":{"foyer":"3 personnes"}}"#)
        let preferences = try await APIKitchenService(client: client).preferences()
        #expect(preferences == ["foyer": "3 personnes"])
        #expect(await client.requests == [.get("v1/preferences")])
    }
}

@Suite("Stock actions")
struct StockActionTests {
    @Test(
        "paths",
        arguments: [
            (StockAction.consume(quantity: nil), "consume"),
            (.waste(quantity: 1, reason: "moisi"), "waste"),
            (.open, "open"),
            (.move(.frigo), "move"),
            (.setBestBefore("2026-12-01"), "best-before"),
        ]
    )
    func path(action: StockAction, expected: String) {
        #expect(action.pathComponent == expected)
    }

    @Test("payloads carry only their own fields")
    func payloads() {
        #expect(StockAction.consume(quantity: 2).payload == .init(quantity: 2))
        #expect(StockAction.waste(quantity: nil, reason: "périmé").payload == .init(reason: "périmé"))
        #expect(StockAction.move(.congelateur).payload == .init(location: .congelateur))
        #expect(StockAction.setBestBefore("2026-12-01").payload == .init(bestBefore: "2026-12-01"))
        #expect(StockAction.open.payload == .init())
    }
}
