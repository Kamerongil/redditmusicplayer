passportSocketIo = require 'passport.socketio'
session = require 'express-session'
SessionFileStore = require('session-file-store') session
cookieParser = require 'cookie-parser'
crypto = require 'crypto'
Constants = require '../src/coffee/Constants'
_ = require 'lodash'

onAuthorizeSuccess = (data, accept) ->
	accept()

onAuthorizeFail = (data, message, error, accept) ->
	accept()

sendToRoomOnTrigger = (socket, type) ->
	socket.on type, (data) ->
		_.each socket.rooms, (room) ->
			socket.to(room).emit type, data

io = null

module.exports = (socketio) ->
	io = socketio
	simpleEvents = [Constants.CONTROLS_FORWARD, Constants.CONTROLS_BACKWARD, Constants.CONTROLS_PLAY, Constants.REMOTE_SUBREDDITS]

	io.use passportSocketIo.authorize
		cookieParser: cookieParser
		key: 'rmp.id'
		secret: 'Reddit Music Player'
		store: new SessionFileStore
			ttl: 60 * 60 * 24 * 30 * 6, # 6 months 
		success: onAuthorizeSuccess
		fail: onAuthorizeFail

	io.on 'connection', (socket) ->
		socket.on 'join:hash', (hash) ->
			socket.join hash
			console.log 'Socket Join ', socket.request.user.name, hash

		if socket.request.user?
			socket.join socket.request.user.name

		for ev in simpleEvents
			sendToRoomOnTrigger socket, ev

module.exports.routes = ->
	@post '/remote/:token/:action', (req, res, next) ->
		token = req.params.token
		action = req.params.action

		socket = _.find io.sockets.sockets, (s) ->
			_.find s.rooms, (r) -> token is r

		if not socket?
			return res.send
				control: action
				status: false
				message: 'Bad token or disconnecsted'

		switch action
			when 'play'
				socket.emit Constants.CONTROLS_PLAY
				res.send
					control: 'play'
					status: true

			when 'forward'
				socket.emit Constants.CONTROLS_FORWARD
				res.send
					control: 'forward'
					status: true

			when 'backward'
				socket.emit Constants.CONTROLS_BACKWARD
				res.send
					control: 'backward'
					status: true

			when 'subreddits'
				subreddits = req.body['subreddits[]']?.join('+')
				subreddits = req.body.subreddits if not subreddits?
				console.log subreddits, req.body
				socket.emit Constants.REMOTE_SUBREDDITS, subreddits
				res.send
					control: 'subreddits'
					subreddits: subreddits
					status: true

	@get '/remote/:token/:action', (req, res, next) ->
		token = req.params.token
		action = req.params.action

		socket = _.find io.sockets.sockets, (s) ->
			_.find s.rooms, (r) -> token is r

		if not socket?
			return res.send
				control: action
				status: false
				message: 'Bad token'

		switch action
			when 'user'
				socket.once 'answer:user', (data) ->
					res.send
						control: 'user'
						status: true
						data: data
				socket.emit 'get:user'
			when 'play'
				socket.once 'answer:play', (data) ->
					res.send
						control: 'play'
						status: true
						data: data
				socket.emit 'get:play'
			when 'subreddits'
				socket.once 'answer:subreddits', (data) ->
					res.send
						control: 'subreddits'
						status: true
						data: data
				socket.emit 'get:subreddits'
			when 'song'
				socket.once 'answer:song', (data) ->
					if data
						res.send
							control: 'song'
							status: true
							data: data
					else
						res.send
							control: 'song'
							status: false
							data: {}
							message: 'No song selected'
				socket.emit 'get:song'
