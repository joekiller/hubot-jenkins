JenkinsApi = require 'jenkins-api'
querystring = require 'querystring'
URL = require 'url-parse'

jenkinsErrorReply = (msg, err, content) ->
  if err or content.statusCode
    msg.reply "error, status= #{content.statusCode}"
    if content.statusCode == 403
      msg.reply "You appear to be unauthorized."
      msg.reply "Setup an auth token with jenkins-token:set <username:token>"

# Holds a list of jobs, so we can trigger them with a number
# instead of the job's name. Gets populated on when calling
# list.
jobList = []
jenkinsApi = null

class Jenkins
  constructor: (auth) ->
    @url = process.env.HUBOT_JENKINS_URL
    if auth?
      [username, password] = auth.split ':'
    else if process.env.HUBOT_JENKINS_AUTH
      [username, password] = process.env.HUBOT_JENKINS_AUTH.split ':'
    jenkinsApi = null
    if username? and password?
      jenkinsApi = JenkinsApi.init(@url, {
        auth: {
          'user': username
          'pass': password
        }
      })
    else
      jenkinsApi = JenkinsApi.init(@url)

  jenkinsBuildById: (msg) ->
  # Switch the index with the job name
    job = jobList[parseInt(msg.match[1]) - 1]

    if job
      msg.match[1] = job
      jenkinsBuild(msg)
    else
      msg.reply "I couldn't find that job. Try `jenkins list` to get a list."

  jenkinsBuild: (msg, buildWithEmptyParameters) ->
    job = querystring.escape msg.match[1]
    params = msg.match[3]

    if params
      params = @parseParams params
    jenkinsApi.build job, params, (err, content) ->
      if err or content.statusCode
        jenkinsErrorReply msg, err, content
      else
        url = new URL(content.location)
        msg.reply "#{content.message} #{url.protocol}//#{url.host}/job/#{job}"

  jenkinsDescribe: (msg) ->
    job = msg.match[1]

    jenkinsApi.job_info job, (err, content) ->
      if err
        jenkinsErrorReply msg, err, content
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

        jenkinsApi.build_info content.name, content.lastBuild.number, (err, content) ->
          if err
            msg.send "error, status= #{content.statusCode}"
          else
            response = ""
            jobstatus = content.result || 'PENDING'
            jobdate = new Date(content.timestamp)
            response += "LAST JOB: #{jobstatus}, #{jobdate}\n"
            msg.send response

  jenkinsLast: (msg) ->
    job = msg.match[1]

    jenkinsApi.last_build_info job, (err, content) ->
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

  jenkinsList: (msg) ->
    filter = new RegExp(msg.match[2], 'i')
    jenkinsApi.all_jobs (err, content) ->
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

  parseParams: (params) ->
    raw_vars = params.split '&'
    parsed_params = {}

    for v in raw_vars
      [key, val] = v.split("=")
      parsed_params[key] = decodeURIComponent(val)

    parsed_params

exports.Jenkins = Jenkins