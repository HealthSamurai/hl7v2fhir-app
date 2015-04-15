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
        if ($rootScope.config || {}).access_token
          config.url = uri.addQuery(
            access_token: $rootScope.config.access_token
          ).toString()
      config

app.run ($rootScope, $window, $location, $http)->
  query = URI($window.location.search).query(true)
  search = $location.search()
  $rootScope.config = {
        base_uri: search.base_uri || query.base_uri
        client_id: search.client_id || query.client_id
        authorize_uri: search.authorize_uri || query.authorize_uri
        redirect_uri: $location.absUrl().replace($location.url(), '/')
        location: $location.absUrl()
        hash: $location.url()
        access_token: search.access_token || query.access_token
        state: search.state || query.state
                }
  $rootScope.user = {}

  unless $rootScope.config.access_token
    authorizeUri = URI($rootScope.config.authorize_uri)
      .setQuery(
        client_id: $rootScope.config.client_id
        redirect_uri: $rootScope.config.redirect_uri
        response_type: 'token'
        scope: 'user'
        state: $location.path()
      ).toString()
    #$window.location.href = authorizeUri
  else
    $http.get($rootScope.config.base_uri.replace(/fhir$/, '') + 'oauth/user?access_token=' + $rootScope.config.access_token)
        .success (data) ->
          $rootScope.user.login = data.login
          $rootScope.user.scope = data.scope

  $rootScope.sitemap = sitemap
  $rootScope.$on  "$routeChangeStart", (event, next, current)->
    activate(next.name)

  #$location.path($rootScope.config.state)

  $rootScope.revoke = () ->
    $http.get($rootScope.config.base.replace(/fhir$/, '') + 'oauth/revoke?access_token=' + $rootScope.config.access_token)
      .success (data) ->
        $rootScope.config = {}
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
