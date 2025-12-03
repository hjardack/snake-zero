import SwiftUI
import Combine

// MARK: - Data Models

enum Direction {
    case up, down, left, right
}

struct Point: Hashable {
    let x: Int
    let y: Int
}

// MARK: - Game Logic Engine

class SnakeGameEngine: ObservableObject {
    // Game Configuration
    let boardSize = 20
    let speed: TimeInterval = 0.15
    
    // Game State
    @Published var snake: [Point] = []
    @Published var food: Point = Point(x: 0, y: 0)
    @Published var score: Int = 0
    @Published var highScore: Int = UserDefaults.standard.integer(forKey: "HighScore") // Load from storage
    @Published var isGameOver: Bool = true
    @Published var isPaused: Bool = false
    @Published var direction: Direction = .right
    
    private var timer: Timer?
    
    func startGame() {
        // Reset state
        snake = [Point(x: 10, y: 10), Point(x: 9, y: 10), Point(x: 8, y: 10)]
        score = 0
        direction = .right
        isGameOver = false
        isPaused = false
        spawnFood()
        
        // Start Game Loop
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { _ in
            self.moveSnake()
        }
    }
    
    func togglePause() {
        isPaused.toggle()
    }
    
    func changeDirection(_ newDirection: Direction) {
        // Prevent changes while paused
        guard !isPaused else { return }
        
        // Prevent 180-degree turns
        switch (direction, newDirection) {
        case (.up, .down), (.down, .up), (.left, .right), (.right, .left):
            return
        default:
            direction = newDirection
        }
    }
    
    private func moveSnake() {
        // Stop movement if game over or paused
        guard !isGameOver, !isPaused else { return }
        
        guard let head = snake.first else { return }
        
        var newHead = head
        
        switch direction {
        case .up:    newHead = Point(x: head.x, y: head.y - 1)
        case .down:  newHead = Point(x: head.x, y: head.y + 1)
        case .left:  newHead = Point(x: head.x - 1, y: head.y)
        case .right: newHead = Point(x: head.x + 1, y: head.y)
        }
        
        // Collision Detection (Walls)
        if newHead.x < 0 || newHead.x >= boardSize || newHead.y < 0 || newHead.y >= boardSize {
            gameOver()
            return
        }
        
        // Collision Detection (Self)
        if snake.contains(newHead) {
            gameOver()
            return
        }
        
        // Move Snake
        snake.insert(newHead, at: 0)
        
        // Eat Food
        if newHead == food {
            score += 1
            spawnFood()
        } else {
            snake.removeLast()
        }
    }
    
    private func spawnFood() {
        var newFood: Point
        repeat {
            newFood = Point(x: Int.random(in: 0..<boardSize), y: Int.random(in: 0..<boardSize))
        } while snake.contains(newFood)
        food = newFood
    }
    
    private func gameOver() {
        isGameOver = true
        timer?.invalidate()
        
        // Save High Score
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "HighScore")
        }
    }
}

// MARK: - SwiftUI View

struct ContentView: View {
    @StateObject private var game = SnakeGameEngine()
    
    var body: some View {
        ZStack {
            // Background Color
            Color(white: 0.1)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header: Score and High Score
                HStack {
                    VStack(alignment: .leading) {
                        Text("Score: \(game.score)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("High Score: \(game.highScore)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Pause Button (Only visible while playing)
                    if !game.isGameOver {
                        Button(action: {
                            game.togglePause()
                        }) {
                            Image(systemName: game.isPaused ? "play.fill" : "pause.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color(white: 0.2))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding()
                
                // Game Board
                GeometryReader { geometry in
                    let cellSize = geometry.size.width / CGFloat(game.boardSize)
                    
                    ZStack {
                        // Grid Background
                        ForEach(0..<game.boardSize, id: \.self) { row in
                            ForEach(0..<game.boardSize, id: \.self) { col in
                                Rectangle()
                                    .fill(Color(white: 0.15))
                                    .frame(width: cellSize - 1, height: cellSize - 1)
                                    .position(
                                        x: CGFloat(col) * cellSize + cellSize / 2,
                                        y: CGFloat(row) * cellSize + cellSize / 2
                                    )
                            }
                        }
                        
                        // Food
                        Circle()
                            .fill(Color.red)
                            .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                            .position(
                                x: CGFloat(game.food.x) * cellSize + cellSize / 2,
                                y: CGFloat(game.food.y) * cellSize + cellSize / 2
                            )
                        
                        // Snake
                        ForEach(game.snake, id: \.self) { part in
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: cellSize - 2, height: cellSize - 2)
                                .position(
                                    x: CGFloat(part.x) * cellSize + cellSize / 2,
                                    y: CGFloat(part.y) * cellSize + cellSize / 2
                                )
                        }
                        
                        // PAUSED Overlay
                        if game.isPaused && !game.isGameOver {
                            Text("PAUSED")
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .background(Color.black)
                .border(Color.white, width: 2)
                .padding()
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            guard !game.isPaused else { return } // No movement if paused
                            
                            let horizontalAmount = value.translation.width
                            let verticalAmount = value.translation.height
                            
                            if abs(horizontalAmount) > abs(verticalAmount) {
                                game.changeDirection(horizontalAmount < 0 ? .left : .right)
                            } else {
                                game.changeDirection(verticalAmount < 0 ? .up : .down)
                            }
                        }
                )
                
                // Game Over / Start Controls
                if game.isGameOver {
                    Button(action: {
                        game.startGame()
                    }) {
                        Text("START GAME")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(width: 200)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)
                } else {
                    Spacer()
                        .frame(height: 70)
                }
                
                Spacer()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
