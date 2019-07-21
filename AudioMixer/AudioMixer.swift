//
//  AudioMixer.swift
//  AudioMixer
//
//  Created by ivan volnov on 7/21/19.
//  Copyright © 2019 ivolnov. All rights reserved.
//

protocol AudioMixer {
    func push(_ chunk: Chunk, channel id: Int)
    func subscribe(consumer: @escaping (Chunk) -> ())
}

struct Chunk {
    let samples: [UInt8]
    let timeStamp: UInt
}

class PcmMixer: AudioMixer {

    struct Config {
        let startTimeStamp: UInt
        let queueLength: Int
        let signalCount: Int
        let chunkSize: UInt
    }
    
    private var consumer: (Chunk) -> () = { _ in }
    private var resultTimeStamp: UInt
    private let chunkSize: UInt
    
    private var queueLastIndexes: [Int] = []
    private var queues: [[UInt8]] = []
    private var mixed: [UInt8] = []
    
    init(config: Config) {
        
        for _ in 0..<config.signalCount {
            let queue = Array(repeating: UInt8(0), count: config.queueLength)
            queues.append(queue)
        }
        
        queueLastIndexes = Array(repeating: 0, count: queues.count)
        resultTimeStamp = config.startTimeStamp
        chunkSize = config.chunkSize
    }
    
    func subscribe(consumer: @escaping (Chunk) -> ()) {
        self.consumer = consumer
    }
    
    func push(_ chunk: Chunk, channel id: Int) {
        
        // means its too late we have to drop it...
        if Int(chunk.timeStamp) + chunk.samples.count < Int(resultTimeStamp) + mixed.count {
            return
        }
        
        // means we don't have anything to mix with yet
        if chunk.timeStamp > Int(resultTimeStamp) + mixed.count {
            append(chunk, to: id)
            return
        }
        
        // lets check other queues, maybe we are ready to mix
        var smallestLastIndex = Int.max
        
        for (channelId, lastIndex) in queueLastIndexes.enumerated() {
            
            if channelId == id {
                continue
            }
            
            // means some queue is still empty - can't mix yet
            if lastIndex == 0 {
                append(chunk, to: id)
                return
            }
            
            smallestLastIndex = min(smallestLastIndex, lastIndex)
        }
        
        // its mix time
        mix(first: smallestLastIndex + 1)
        
        if mixed.count == chunkSize {
            deliver()
        }
    }
    
    private func append(_ chunk: Chunk, to id: Int) {
        
        var queue = queues[id]
        
        // is there enough room for this chunk in the queue?
        let overflow = queueLastIndexes[id] + 1 + chunk.samples.count - queue.count
        
        // we can't wait anymore lets mix what we have to free some space
        if overflow > 0 {
            mix(first: overflow)
        }
        
        // copy
        for index in 0..<chunk.samples.count {
            let queueIndex = queueLastIndexes[id] + index
            queue[queueIndex] = chunk.samples[index]
        }
        
        queueLastIndexes[id] += chunk.samples.count - 1
        
        if mixed.count == chunkSize {
            deliver()
        }
    }
    
    private func mix(first count: Int) {
        // Ideally we have to normalize signals prior to mixing
        // as it will most likely clip when having many channels
        for index in 0..<count {
            var byte: Int = 0
            for queue in queues {
                byte += Int(queue[index])
            }
            // clipping
            byte = min(byte, Int(UInt8.max))
            byte = max(byte, Int(UInt8.min))
            mixed.append(UInt8(byte))
        }
        // clean up the queues
        for id in 0..<queues.count {
            
            queueLastIndexes[id] -= count - 1
            
            let leftovers = queues[id][count...]
            let total = queues[id].count
            if leftovers.count > 0 {
                queues[id] = Array(leftovers) + Array(repeating: 0, count: total - leftovers.count)
            }
        }
    }
    
    private func deliver() {
        
        let chunk = Chunk(samples: mixed,
                          timeStamp: resultTimeStamp)
        
        // clean up
        resultTimeStamp = resultTimeStamp + chunkSize
        mixed = []
        
        consumer(chunk)
    }
}
