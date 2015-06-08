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
#   dougcole

Path  = require("path")
JenkinsApi = require 'jenkins-api'
querystring = require 'querystring'

# Holds a list of jobs, so we can trigger them with a number
# instead of the job's name. Gets populated on when calling
# list.
jobList = []

parseParams = (params) ->
  raw_vars = params.split '&'

  parsed_params = {}

  for v in raw_vars
    [key, val] = v.split("=")
    parsed_params[key] = decodeURIComponent(val)

  parsed_params

initJenkins = () ->
  url = process.env.HUBOT_JENKINS_URL
  if process.env.HUBOT_JENKINS_AUTH
    [username, password] = process.env.HUBOT_JENKINS_AUTH.split ':'
    jenkins = JenkinsApi.init(url, {
      auth: {
        'user': username
        'pass': password
      }
    })
  else
    jenkins = JenkinsApi.init(url)

  [jenkins, url]

jenkinsBuildById = (msg) ->
  # Switch the index with the job name
  job = jobList[parseInt(msg.match[1]) - 1]

  if job
    msg.match[1] = job
    jenkinsBuild(msg)
  else
    msg.reply "I couldn't find that job. Try `jenkins list` to get a list."

jenkinsBuild = (msg, buildWithEmptyParameters) ->
  [jenkins, url] = initJenkins()

  job = querystring.escape msg.match[1]
  params = msg.match[3]

  if params
    params = parseParams params
  jenkins.build job, params, (err, response) ->
    if err or response.statusCode
      msg.reply "error, status= #{response.statusCode}"
    else
      msg.reply "#{response.message} #{url}/job/#{job}"

jenkinsDescribe = (msg) ->
  [jenkins, url] = initJenkins()
  job = msg.match[1]

  jenkins.job_info job, (err, content) ->
    if err
      msg.send "error, status= #{content.statusCode}"
    else
      response = ""
      response += "JOB: #{content.displayName}\n"
      response += "URL: #{content.url}\n"
      response += "\n"
      if content.description
        response += "DESCRIPTION: #{content.description}\n"

      response += "ENABLED: #{content.buildable}\n"
      response += "STATUS: #{content.color}\n"

      tmpReport = ""
      if content.healthReport.length > 0
        for report in content.healthReport
          tmpReport += "\n  #{report.description}"
      else
        tmpReport = " unknown"
      response += "HEALTH: #{tmpReport}\n"

      parameters = ""
      for item in content.actions
        if item.parameterDefinitions
          for param in item.parameterDefinitions
            tmpDescription = if param.description then " - #{param.description} " else ""
            tmpDefault = if param.defaultParameterValue then " (default=#{param.defaultParameterValue.value})" else ""
            parameters += "\n  #{param.name}#{tmpDescription}#{tmpDefault}"

      if parameters != ""
        response += "PARAMETERS: #{parameters}\n"

      msg.reply response

      if not content.lastBuild
        return

      jenkins.build_info content.name, content.lastBuild.number, (err, content) ->
        if err
          msg.send "error, status= #{content.statusCode}"
        else
          response = ""
          jobstatus = content.result || 'PENDING'
          jobdate = new Date(content.timestamp)
          response += "LAST JOB: #{jobstatus}, #{jobdate}\n"
          msg.send response

jenkinsLast = (msg) ->
  [jenkins, url] = initJenkins()
  job = msg.match[1]

  jenkins.last_build_info job, (err, content) ->
    if err
      msg.send "error, status= #{content.statusCode}"
    else
      response = ""
      response += "NAME: #{content.fullDisplayName}\n"
      response += "URL: #{content.url}\n"

      if content.description
        response += "DESCRIPTION: #{content.description}\n"

      response += "BUILDING: #{content.building}\n"

      msg.send response

jenkinsList = (msg) ->
  [jenkins, url] = initJenkins()
  filter = new RegExp(msg.match[2], 'i')
  jenkins.all_jobs (err, content) ->
    if err
      msg.send "error, status= #{content.statusCode}"
    else
      msg.send "#{JSON.stringify content}"
      response = ""
      for job in content
      # Add the job to the jobList
        index = jobList.indexOf(job.name)
        if index == -1
          jobList.push(job.name)
          index = jobList.indexOf(job.name)

        state = if job.color == "red" then "FAIL" else "PASS"
        if filter.test job.name
          response += "[#{index + 1}] #{state} #{job.name}\n"
      msg.send response

module.exports = (robot) ->
  robot.respond /j(?:enkins)? build ([\w\.\-_ ]+)(, (.+))?/i, (msg) ->
    jenkinsBuild(msg, false)

  robot.respond /j(?:enkins)? b (\d+)/i, (msg) ->
    jenkinsBuildById(msg)

  robot.respond /j(?:enkins)? list( (.+))?/i, (msg) ->
    jenkinsList(msg)

  robot.respond /j(?:enkins)? describe (.*)/i, (msg) ->
    jenkinsDescribe(msg)

  robot.respond /j(?:enkins)? last (.*)/i, (msg) ->
    jenkinsLast(msg)

  robot.jenkins = {
    list: jenkinsList,
    build: jenkinsBuild
    describe: jenkinsDescribe
    last: jenkinsLast
  }