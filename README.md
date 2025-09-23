# ggb-teststand

## Node-Red
1. After cloning the repository, change to the node-red-data directory and run npm install.

## STM32 Cube Programmer Container
### stm32\_flash\_cli

This is a standalone Docker container that starts with Ubuntu and has STM32 Cube Programmer installed.

The cube programmer install is in the en.stm32cubeprg-lin-v2-18-0 directory and needs to to manually installed
once the container is up and running.

To build the image:
1. Run this command in the stm32\_flash\_cli directory.
    ```
    docker build -t stm32_flash_cli:0.1 .
    ```
2. Start the continer:
    ```
    docker run -it stm32_flash_cli:0.1
    ```
3. Change to the /home/ubuntu/en.stm32cubeprg-lin-v2-18-0 directory
4. Run the cube programmer installer. Defaults are all good.
    ```
    ./SetupSTM32CubeProgrammer-2.18.0.linux
    ```
5. The STM32CubeProgrammer executable is located here:
    ```
    /usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI
    ```
6. Find the Container ID of the running image from above
    ```
    docker ps
    ```
7. Now we need to save the running container with the cube programmer installed. 
   **DO NOT STOP THE RUNNING CONTAINER BEFORE THIS STEP**
    ```
    docker commit CONTAINER ID stm32_flash_cli:0.2

---

### stm32_flash_api

This container is build on top of previously build STM32 Cube Programmer CLI container (stm32_flash_cli)

This container installs Python and Flask to create api enpoints for the cube programmer

To build the image:
1. Run this command in the stm32\_flash\_api directory
    ```
    docker build -t stm32_flash_api:0.1 .
    ```
2. To test if container works:
    ```
    docker run -v /dev:/dev --device /dev:/dev --net=host -it stm32_flash_api:0.1
    ```
3. Open a browser and go to /<container IP/>:5000/info

---

## Docker Compose

To start the Test Stand run the following command:
    ```
    docker compose -f docker\_compose.yml up
    ```

