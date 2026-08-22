import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("enderPulse.dependencyCheck", ["sh", "-c", "command -v cava"],
            function(stdout, exitCode) {
                if (exitCode === 0) {
                    done(null)
                    return
                }

                done({
                    "title": I18n.tr("Cava is required"),
                    "details": I18n.tr("Install the 'cava' audio visualizer with your distribution's package manager, then enable EnderPulse again.")
                })
            })
    }
}
