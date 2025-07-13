FROM node:18-alpine

WORKDIR /app

COPY package.json .
RUN npm install

COPY simple-api.js .

EXPOSE 3001

CMD ["npm", "start"]
