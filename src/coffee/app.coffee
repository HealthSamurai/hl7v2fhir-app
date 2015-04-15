require('../../bower_components/angular/angular.js')
require('../../bower_components/angular-route/angular-route.js')
require('../../bower_components/angular-sanitize/angular-sanitize.js')
require('../../bower_components/angular-animate/angular-animate.js')
require('../../bower_components/angular-cookies/angular-cookies.js')
require('../../bower_components/fhir-bower/ngFhir.js')

require('file?name=index.html!../index.html')
require('file?name=fhir.json!../fhir.json')
require('../less/app.less')

URI = require('../../bower_components/uri.js/src/URI.js')

app = require('./module')

require('./views')
require('./data')

sitemap = require('./sitemap')

log = require('./logger')

baseUrl = require('./baseurl')
oauthConfig = require('./oauth_config')()

app.config ($routeProvider) ->
  rp = $routeProvider
    .when '/',
      templateUrl: '/views/index.html'
      controller: 'WelcomeCtrl'
    .when '/redirect',
      templateUrl: '/views/redirect.html'
      controller: 'RedirectCtrl'

  mkRoute = (acc, x)->
    acc.when("/#{x.name}", x)

  rp = sitemap.main.reduce mkRoute, rp

  rp.otherwise
    templateUrl: '/views/404.html'

activate = (name)->
  sitemap.main.forEach (x)->
    if x.name == name
      x.active = true
    else
      delete x.active

app.config ($fhirProvider, $httpProvider) ->
  $fhirProvider.baseUrl = baseUrl()
  $httpProvider.interceptors.push ($q, $timeout, $rootScope) ->
    request: (config) ->
      uri = URI(config.url)
      unless uri.path().match(/^\/(views|oauth)/)
        if oauthConfig.response_type && ($rootScope.oauth || {}).access_token
          config.url = uri.addQuery(
            access_token: $rootScope.oauth.access_token
          ).toString()
      config

app.run ($rootScope)->
  $rootScope.sitemap = sitemap
  $rootScope.$on  "$routeChangeStart", (event, next, current)->
    activate(next.name)

app.run ($rootScope, $window, $location, $http)->
  $rootScope.user = {}

  if oauthConfig.response_type
    queryString = URI($window.location.search).query(true)
    code = $location.search().code || queryString.code
    accessToken = $location.search().access_token || queryString.access_token
    $rootScope.oauth = {}
    $rootScope.oauth.code = code if code
    $rootScope.oauth.access_token = accessToken if accessToken
    if oauthConfig.response_type == 'token'
      if !$rootScope.oauth.access_token
        authorizeUri = URI(oauthConfig.authorize_uri)
          .setQuery(
            client_id: oauthConfig.client_id
            redirect_uri: oauthConfig.redirect_uri
            response_type: oauthConfig.response_type
            scope: oauthConfig.scope
          ).toString()
        $window.location.href = authorizeUri
      else
        $http.get(baseUrl().replace(/fhir$/, '') + 'oauth/user?access_token=' + $rootScope.oauth.access_token)
          .success (data) ->
            $rootScope.user.login = data.login
            $rootScope.user.scope = data.scope


  $rootScope.sitemap = sitemap
  $rootScope.$on  "$routeChangeStart", (event, next, current)->
    activate(next.name)

  $rootScope.revoke = () ->
    $http.get(baseUrl().replace(/fhir$/, '') + 'oauth/revoke?access_token=' + $rootScope.oauth.access_token)
      .success (data) ->
        $rootScope.oauth = {}
        $location.url($location.path())
        $window.location.reload();

app.controller 'RedirectCtrl',
  ($scope, $rootScope, $http, $location) ->
    if oauthConfig.response_type == 'token'
      $location.path('/')

app.controller 'WelcomeCtrl', ($scope, $fhir)->
  $scope.header = "WelcomeCtrl"
  $fhir.search(type: 'Alert', query: {})
    .success (data)->
      $scope.data = data

app.controller 'Page1Ctrl', ($scope, $routeParams)->
  $scope.header = "Page1Ctrl"
  $scope.params = $routeParams

app.controller 'Page2Ctrl', ($scope, $routeParams)->
  $scope.header = "Page2Ctrl"
  $scope.params = $routeParams

app.controller 'ProfileCtrl', ($scope, $routeParams)->
  $scope.header = "ProfileCtrl"
