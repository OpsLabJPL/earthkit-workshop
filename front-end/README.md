EarthKit Workshop Front End
===========================

Installation & Usage
--------------------

### Language Pre-Reqs
+ node.js
+ ruby

### Build Instructions
```
$ npm install
# npm install grunt-cli bower -g
# gem install compass
$ bower install
$ grunt handlebars
```

### Running the Development Web Server
For development purposes, a local web server can be launched with grunt. By
default the server launches on localhost port 9000.
```
$ grunt server
```

### Production Deployment Notes
The front-end is comprised of all static HTML/CSS/JS and in production can be
served directly with a server like Nginx or hosted with a service like Amazon
S3. The `app/` directory is the root of all the static content that needs to be
served. The `flatten.sh` script can be referred to as an example of how to build
the project with grunt and subsequently launch nginx.

External Assets
---------------

Various external Google Docs files are used to specify all of the lab tutorial
content. A root level Google Docs spreadsheet acts as an index that holds
references to all of the lab tutorials, and each lab tutorial is specified
in a Google Docs text document.

The Google Docs ID of the root level spreadsheet can be specified using the
`LAB_SPREADSHEET_KEY` within the `app/scripts/components/dataLoader.js` file.
