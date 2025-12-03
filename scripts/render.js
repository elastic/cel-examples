// render.js
const fs = require('fs');
const Handlebars = require('handlebars');

// ✅ Register custom helpers
Handlebars.registerHelper('contains', function (array, value, options) {
    if (Array.isArray(array) && array.includes(value)) {
        return options.fn(this); // Render block if condition is true
    }
    return options.inverse(this); // Else block ({{else}})
});

// Load JSON data
const data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));

// Load template
const template = fs.readFileSync(process.argv[3], 'utf8');

// Compile and render
const output = Handlebars.compile(template)(data);

console.log(output);
