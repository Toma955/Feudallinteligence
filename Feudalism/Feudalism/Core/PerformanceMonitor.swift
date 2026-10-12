//
//  PerformanceMonitor.swift
//  Feudalism
//
//  Procesor, grafika, sličice u sekundi i memorija.
//

import Foundation
import Darwin
import Metal

final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    @Published var fps: Int = 0
    @Published var frameMs: Double = 0
    @Published var cpuPercent: Double = 0
    @Published var appRamMB: Double = 0
    @Published var systemRamUsedGB: Double = 0
    @Published var systemRamTotalGB: Double = 0
    @Published var gpuName: String = "—"
    @Published var gpuAllocatedMB: Double = 0

    private var timer: Timer?
    private var lastCPU = host_cpu_load_info()
    private var hasCPUSample = false
    private var frameCount = 0
    private var windowStart: TimeInterval = 0
    private let lock = NSLock()

    func noteFrame(at time: TimeInterval) {
        lock.lock()
        if windowStart == 0 {
            windowStart = time
            lock.unlock()
            return
        }
        frameCount += 1
        let elapsed = time - windowStart
        guard elapsed >= 0.5 else {
            lock.unlock()
            return
        }
        let measured = Double(frameCount) / elapsed
        frameCount = 0
        windowStart = time
        lock.unlock()
        let ms = measured > 0 ? 1000 / measured : 0
        DispatchQueue.main.async {
            self.fps = Int(measured.rounded())
            self.frameMs = ms
        }
    }

    func start() {
        if gpuName == "—" {
            gpuName = MTLCreateSystemDefaultDevice()?.name ?? "Metal"
        }
        guard timer == nil else { return }
        sample()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.sample()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        cpuPercent = readCPU()
        appRamMB = readAppRamMB()
        let memory = readSystemRam()
        systemRamUsedGB = memory.used
        systemRamTotalGB = memory.total
        if let device = MTLCreateSystemDefaultDevice() {
            gpuName = device.name
            gpuAllocatedMB = Double(device.currentAllocatedSize) / (1024 * 1024)
        }
    }

    private func readCPU() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return cpuPercent }
        defer {
            lastCPU = info
            hasCPUSample = true
        }
        guard hasCPUSample else { return cpuPercent }
        let user = Double(info.cpu_ticks.0 &- lastCPU.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1 &- lastCPU.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 &- lastCPU.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 &- lastCPU.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return min(100, (user + system + nice) / total * 100)
    }

    private func readAppRamMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return appRamMB }
        return Double(info.resident_size) / (1024 * 1024)
    }

    private func readSystemRam() -> (used: Double, total: Double) {
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (systemRamUsedGB, total) }
        let page = Double(vm_kernel_page_size)
        let usedPages = Double(stats.active_count + stats.wire_count + stats.compressor_page_count)
        let used = usedPages * page / 1_073_741_824
        return (used, total)
    }
}
