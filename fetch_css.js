const https = require('https');
const fs = require('fs');

https.get('https://kotlin-parser-frontend.onrender.com/assets/index-Dx2iVOty.css', res => {
  let css = '';
  res.on('data', c => css += c);
  res.on('end', () => {
    fs.writeFileSync('e:/C LANGUAGE/target.css', css);
    console.log('Saved target.css, length:', css.length);
  });
});

