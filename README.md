# AudioMixer

### A test task for Expload Arena's iOS developer job position.

A basic audio mixer for [PCM](https://en.wikipedia.org/wiki/Pulse-code_modulation) signals.
Never tested.
Usage:
```
func foo() {
    
    let config = PcmMixer.Config(startTimeStamp: 0,
                                 queueLength: 10 * 1000,
                                 signalCount: 2,
                                 chunkSize: 1024)
    let mixer: AudioMixer = PcmMixer(config: config)
    
    mixer.subscribe() { chunk in
        // result handling
    }
    
    let chunk = Chunk(samples: [], timeStamp: 0)
    mixer.push(chunk, channel: 0)
}
```
