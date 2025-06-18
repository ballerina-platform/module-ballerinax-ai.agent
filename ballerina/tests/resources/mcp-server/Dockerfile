# Use an official Node.js base image
FROM node:20

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the project files
COPY . .

# Build the TypeScript project
RUN npm run build

# Run the server directly using node
CMD ["node", "build/index.js"]
