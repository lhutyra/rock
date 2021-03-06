import os/[Process, JobPool], math/Random

pool := JobPool new()
"Default parallelism = %d" printfln(pool parallelism)

for (i in 0..3) {
    duration := 0.1 * Random randInt(1, 4)
    "Sleeping for %.1fs" printfln(duration)

    args := ["sleep", "#{duration}"]
    version (windows) {
        args = ["cmd", "/c", "ver"]
    }

    p := Process new(args)
    p executeNoWait()
    pool add(Job new(p))
}

pool waitAll()
"Pass" println()

