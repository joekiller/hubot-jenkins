# Description
#   Enable builds from chat that correctly attribute you as the creator
#
# Commands:
#   hubot jenkins-token:set <token> - Sets your user's build username and token.
#   hubot jenkins-token:reset - Resets your user's build token.
#
supported_tasks = [ "jenkins-token" ]

Path           = require("path")
###########################################################################
module.exports = (robot) ->
  robot.respond ///jenkins-token:set (.*)///i, (msg) ->
    token = msg.match[1].trim()

    msg.reply "I stored your token for future use."
    user = robot.brain.userForId msg.envelope.user.id
    user.jenkinsAuth = token

  robot.respond ///jenkins-token:reset///i, (msg) ->
    user = robot.brain.userForId msg.envelope.user.id
    delete(user.jenkinsAuth)
    msg.reply "I nuked your jenkins token. I'll use my default token until you configure another."
