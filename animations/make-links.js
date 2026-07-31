const fs = require('fs');
const path = require('path');

// Your base URL structure
const baseUrl = 'https://onyxv2.lol/Animations/';
const outputFile = 'animation_links.lua';

try {
  // Read all files in the current directory
  const files = fs.readdirSync(__dirname);
  
  // Filter out directories and scripts
  const validFiles = files.filter(file => {
    const isFile = fs.statSync(path.join(__dirname, file)).isFile();
    return isFile && file !== 'make-links.js' && file !== outputFile && file !== 'download.js';
  });

  // Build the Lua dictionary lines
  const luaLines = validFiles.map(file => {
    // URL-encode special characters like spaces, quotes, etc., safely for the web
    const encodedUrl = `${baseUrl}${encodeURIComponent(file)}`;
    
    // Escape any double quotes in the filename so it doesn't break the Lua string layout
    const safeFileName = file.replace(/"/g, '\\"');
    
    return `    ["${safeFileName}"] = "${encodedUrl}",`;
  });

  // Wrap it in the return block layout
  const outputContent = `return {\n${luaLines.join('\n')}\n}`;

  // Write it out
  fs.writeFileSync(outputFile, outputContent, 'utf8');
  
  console.log(`Success! Formatted ${validFiles.length} files into Lua layout inside ${outputFile}`);
} catch (err) {
  console.error('Error creating Lua dictionary:', err);
}