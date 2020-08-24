express = require 'express'
bodyParser = require 'body-parser'

cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'
session = require 'express-session'
SessionFileStore = require('session-file-store') session

passport = require 'passport'
jade = require 'jade'
RedditStrategy = require('passport-reddit').Strategy

logger = require 'morgan'

# Configure Authentication
reddit = require './reddit'
passport.serializeUser (user, done) ->
	done null, user

passport.deserializeUser (obj, done) ->
	done null, obj

passport.use new RedditStrategy
	clientID: reddit.client_id
	clientSecret: reddit.secret
	callbackURL: reddit.redirect_uri
	scope: reddit.scope
	, (accessToken, refreshToken, profile, done) ->
		process.nextTick () ->
			done null, profile, refreshToken

module.exports = ->
	baseDir = @set 'baseDir'

	# The port the server should run on
	@set 'port', process.env.PORT or 4008

	@set 'view engine', 'jade'
	@set 'views', baseDir + '/src/jade'

	# Set the server's public directory
	@use express.static(baseDir + '/app')

	@use logger 'dev'

	@use cookieParser()
	@use bodyParser.json()
	@use bodyParser.urlencoded extended: false
	@use session
		resave: true
		saveUninitialized: true
		name: 'rmp.id'
		secret: 'Reddit Music Player'
		store: new SessionFileStore
			ttl: 60 * 60 * 24 * 30,
		cookie:
			secure: false
			maxAge: 30 * (24 * 60 * 60 * 1000) # days

	# Authentication
	@use passport.initialize()
	@use passport.session()
