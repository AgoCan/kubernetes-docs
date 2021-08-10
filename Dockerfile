FROM node:10.24.1-alpine3.11 as builder
COPY . /app
RUN npm config set -g registry https://registry.npm.taobao.org && \
    npm install gitbook-cli -g 
RUN cd /app && \
    npm install  gitbook-plugin-highlight gitbook-plugin-toggle-chapters gitbook-plugin-codeblock-filename gitbook-plugin-sectionx gitbook-plugin-splitter gitbook-plugin-search gitbook-plugin-lunr gitbook-plugin-search-pro gitbook-plugin-theme-default gitbook-plugin-prism gitbook-plugin-prism-themes gitbook-plugin-theme-comscore gitbook-plugin-include gitbook-plugin-favicon gitbook-plugin-anchors gitbook-plugin-tbfed-pagefooter gitbook-plugin-hide-element gitbook-plugin-3-ba gitbook-plugin-donate && \
    gitbook install && \
    gitbook build 

FROM nginx
COPY --from=builder /app/_book /usr/share/nginx/html
