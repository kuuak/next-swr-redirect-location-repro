const http = require('node:http');

const setHeader = http.ServerResponse.prototype.setHeader;
http.ServerResponse.prototype.setHeader = function (name, value) {
	if (String(name).toLowerCase() === 'location') {
		console.log('[trace] setHeader location', value, 'headersSent=', this.headersSent);
		try {
			return setHeader.call(this, name, value);
		} catch (err) {
			console.log('[trace] setHeader threw', err.code);
			throw err;
		}
	}
	return setHeader.call(this, name, value);
};
