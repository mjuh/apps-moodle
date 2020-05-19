buildWebService(
    testHook: {
        String result = "tmp/${env.JOB_NAME}"
        sh "mkdir --parent $result"
        (sh (script: "nix-build --no-out-link tests.nix", returnStdout: true)).trim().split("\n").each{ directory ->
            (sh (String.format("cp --dereference --recursive $directory $result/%s",
                               sh (script: "basename $directory", returnStdout: true))))
        }
        sh "find $result -exec chmod u+w {} +"
        archiveArtifacts (artifacts: "$result/**")
        sh "rm --force --recursive $result"
    }
)
