import Foundation
import Combine
//timer
class TimerManager: ObservableObject {
    @Published private(set) var elapsedSeconds: Double = 0
    
    private var timer: Timer? = nil
    
    func start() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 0.1
        }
        
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        stop()
        elapsedSeconds = 0
    }
    
    func getSeconds() -> Double {
        return elapsedSeconds
    }
}

//standard deviation
extension Array where Element == Double {
    func standardDeviation() -> Double {
        guard !isEmpty else { return 0 }

        let mean = reduce(0, +) / Double(count)
        let variance = reduce(0) { $0 + pow($1 - mean, 2) } / Double(count)
        return sqrt(variance)
    }
}
