require('../../bower_components/angular/angular.js')
require('../../bower_components/angular-route/angular-route.js')
require('../../bower_components/angular-sanitize/angular-sanitize.js')
require('../../bower_components/angular-animate/angular-animate.js')
require('../../bower_components/angular-cookies/angular-cookies.js')
require('../../bower_components/fhir.js/dist/ngFhir.js')

require('file?name=index.html!../index.html')
require('file?name=fhir.json!../fhir.json')
require('../less/app.less')

app = require('./module')

require('./views')
require('./data')

sitemap = require('./sitemap')

log = require('./logger')

app.config ($routeProvider) ->
  rp = $routeProvider
    .when '/',
      templateUrl: '/views/index.html'
      controller: 'WelcomeCtrl'

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

app.config ($fhirProvider)->
  $fhirProvider.baseUrl = 'http://try-fhirplace.hospital-systems.com'

app.run ($rootScope)->
  $rootScope.sitemap = sitemap
  $rootScope.$on  "$routeChangeStart", (event, next, current)->
    activate(next.name)

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
