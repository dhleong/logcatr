'use strict'

### Directives ###

# register the module with Angular
angular.module('app.directives', [
  # require the 'app.service' module
  'app.services'
])

.directive('appVersion', [
  'version'

(version) ->

    (scope, elm, attrs) ->
        elm.text(version)
])

.directive('serverAddr', [
  'readableStatus'

(readableStatus) ->

    (scope, elm, attrs) ->
        elm.html readableStatus
])

.directive('device', [
    'imageFetcher'
(imageFetcher) ->
    restrict: 'E'
    templateUrl: '/partials/device-element.html'
    scope:
        info: '='
    
    link: ($scope, $el, $attr) ->

        imageFetcher.fetch($scope.info)
        .then (deviceImage) ->
            console.log 'fetched!', deviceImage
            $scope.deviceImage = deviceImage
            $scope.$apply()
])
        
.directive 'logcatEntry', ->
    restrict: 'E'
    templateUrl: '/partials/logcat-entry.html'
    scope:
        entry: '='

    link: ($scope, $el, $attr) ->
        entry = $scope.entry
        
        $scope.date = entry.date
        $scope.tag = entry.tag
        $scope.priority = entry.priority
        $scope.priorityClass = {
            2: 'verbose'
            3: 'debug'
            4: 'info'
            5: 'warn'
            6: 'error'
            7: 'fatal'
        }[entry.priority]

        # NB we may mangle this before assigning it to the scope...
        message = entry.message

        # detect json in the message
        objStart = message.indexOf '{'
        objEnd = message.lastIndexOf '}'
        if ~objStart and ~objEnd
            try
                jsonRaw = message.substr objStart, objEnd
                $scope.json = JSON.stringify(JSON.parse(jsonRaw), undefined, 2)
                message = message.substr(0, objStart) + '(json)' + message.substr(objEnd+1)
            catch error
                # not actual json obj... oh well

        # detect stacktraces
        if message.match /^\W*at/m
            $scope.stacktrace = message
            message = '(stacktrace)'

        # TODO linkify URLs?

        $scope.message = message
