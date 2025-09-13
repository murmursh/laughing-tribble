var params = new URLSearchParams(window.location.search)

$(function () {
	var initStateLoginThrottle = $('#initial-state-core-loginThrottleDelay').val()
	if (initStateLoginThrottle && JSON.parse(atob(initStateLoginThrottle)) >= 1600) {
        	if (JSON.parse(atob(initStateLoginThrottle)) === 25000) {
            		alert('Your IP address is blocked. Please contact us via https://nextcloud.com/contact');
	        } else {
        	    alert('Automatic login is disabled. Please try manual login.');
        	}
		return
	}

	if ($('#body-login').length && params.has('user')) {
		console.debug('automatically logging in');
		$('input[name=password]').val('demo');
		$('form[name=login]').submit();
	}
})
