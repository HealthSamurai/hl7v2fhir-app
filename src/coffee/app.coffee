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

mkRoute = (acc, x)->
  acc.when("/#{x.name}", x)

app.config ($routeProvider) ->
  rp = $routeProvider.when '/',
    templateUrl: '/views/home.html'
    controller: 'HomeCtrl'

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
        if ($rootScope.oauth || {}).access_token
          config.url = uri.addQuery(
            access_token: $rootScope.oauth.access_token
          ).toString()
      config

app.run ($rootScope)->
  $rootScope.sitemap = sitemap
  $rootScope.$on  "$routeChangeStart", (event, next, current)->
    activate(next.name)

app.run ($rootScope, $window, $location, $http)->
  $rootScope.config = {
        base: baseUrl()
        client_id: oauthConfig.client_id
        authorize_uri: oauthConfig.authorize_uri
        redirect_uri: oauthConfig.redirect_uri
        location: $location.path()
        }
  $rootScope.user = {}

  queryString = URI($window.location.search).query(true)
  accessToken = $location.search().access_token || queryString.access_token
  state = $location.search().state || queryString.state
  $rootScope.config.access_token = accessToken
  $rootScope.config.state = state
  $rootScope.oauth = {}
  $rootScope.oauth.access_token = accessToken if accessToken
  if !$rootScope.oauth.access_token
    authorizeUri = URI(oauthConfig.authorize_uri)
      .setQuery(
        client_id: oauthConfig.client_id
        redirect_uri: oauthConfig.redirect_uri
        response_type: 'token'
        scope: 'user'
        state: $location.path()
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

  $location.path($rootScope.config.state)

  $rootScope.revoke = () ->
    $http.get(baseUrl().replace(/fhir$/, '') + 'oauth/revoke?access_token=' + $rootScope.oauth.access_token)
      .success (data) ->
        $rootScope.oauth = {}
        $location.url($location.path())
        $window.location.reload();

app.controller 'HomeCtrl', ($scope, $fhir)->
  $scope.header = "HomeCtrl"
  $fhir.search(type: 'Alert', query: {})
    .success (data)->
      $scope.data = data

app.controller 'PageCtrl', ($scope, $routeParams)->
  $scope.header = "PageCtrl"
  $scope.params = $routeParams
