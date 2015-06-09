# Description:
#   Interact with your Jenkins CI server
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JENKINS_URL
#   HUBOT_JENKINS_AUTH
#
#   Auth should be in the "user:password" format.
#
# Commands:
#   hubot jenkins b <jobNumber> - builds the job specified by jobNumber. List jobs to get number.
#   hubot jenkins build <job> - builds the specified Jenkins job
#   hubot jenkins build <job>, <params> - builds the specified Jenkins job with parameters as key=value&key2=value2
#   hubot jenkins list <filter> - lists Jenkins jobs
#   hubot jenkins describe <job> - Describes the specified Jenkins job
#   hubot jenkins last <job> - Details about the last build for the specified Jenkins job

#
# Author:
#   dougcole and joekiller (Joe Lawson)

Path  = require("path")
Jenkins = require(Path.join(__dirname, "..", "jenkins")).Jenkins

module.exports = (robot) ->
  jenkinsUserAuth = (msg) ->
    user = robot.brain.userForId msg.envelope.user.id
    if user? and user.jenkinsAuth?
      new Jenkins(user.jenkinsAuth)
    else
      new Jenkins()

  robot.respond /j(?:enkins)? build ([\w\.\-_ ]+)(, (.+))?/i, (msg) ->
    jenkins = jenkinsUserAuth(msg)
    jenkins.jenkinsBuild(msg, false)

  robot.respond /j(?:enkins)? b (\d+)/i, (msg) ->
    jenkins = jenkinsUserAuth(msg)
    jenkins.jenkinsBuildById(msg)

  robot.respond /j(?:enkins)? list( (.+))?/i, (msg) ->
    jenkins = jenkinsUserAuth(msg)
    jenkins.jenkinsList(msg)

  robot.respond /j(?:enkins)? describe (.*)/i, (msg) ->
    jenkins = jenkinsUserAuth(msg)
    jenkins.jenkinsDescribe(msg)

  robot.respond /j(?:enkins)? last (.*)/i, (msg) ->
    jenkins = jenkinsUserAuth(msg)
    jenkins.jenkinsLast(msg)

