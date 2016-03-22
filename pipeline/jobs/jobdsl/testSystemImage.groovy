jobName = 'test-system-image'
awsRegion = 'us-west-2'
customActionTypeVersion = 3

job(jobName) {
  triggers {
    scm("* * * * *")
  }

  steps {
    shell(readFileFromWorkspace("pipeline/jobs/bash/${jobName}.sh"))
  }

  configure { project ->
    project.remove(project / scm) // remove the existing 'scm' element

    project / scm(class: 'com.amazonaws.codepipeline.jenkinsplugin.AWSCodePipelineSCM', plugin: 'codepipeline@0.8') {
      clearWorkspace true
      actionTypeCategory 'Test'
      actionTypeProvider jobName
      projectName jobName
      actionTypeVersion customActionTypeVersion
      region awsRegion
    }

    project.remove(project / publishers)

    project / publishers / 'com.amazonaws.codepipeline.jenkinsplugin.AWSCodePipelinePublisher'(plugin:'codepipeline@0.8') {
      buildOutputs {
        'com.amazonaws.codepipeline.jenkinsplugin.AWSCodePipelinePublisher_-OutputTuple' {
          outputString ''
        }
      }
    }
  }
}