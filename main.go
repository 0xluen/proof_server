package main

import (
    "encoding/json"
    "io/ioutil"
    "log"
    "net/http"
    "os"
    "strings"

    "github.com/gofiber/fiber/v2"
    "github.com/gofiber/fiber/v2/middleware/cors"
)

type Wallet struct {
    Address string   `json:"address"`
    Proof   []string `json:"proof"`
}

type Data struct {
    RootHash string   `json:"rootHash"`
    Wallets  []Wallet `json:"wallets"`
}

func main() {
    app := fiber.New()

    app.Use(cors.New(cors.Config{
        AllowOrigins: "*",  
        AllowHeaders: "Origin, Content-Type, Accept",
    }))

    var data Data
    file, err := ioutil.ReadFile("data.json")
    if err != nil {
        log.Fatal("Error reading the JSON file:", err)
        os.Exit(1)
    }

    err = json.Unmarshal(file, &data)
    if err != nil {
        log.Fatal("Error unmarshaling JSON data:", err)
        os.Exit(1)
    }

    app.Get("/getProof", func(c *fiber.Ctx) error {
        address := c.Query("address")
        if address == "" {
            return c.Status(http.StatusBadRequest).SendString("Address is required")
        }

        for _, wallet := range data.Wallets {
            if strings.EqualFold(wallet.Address, address) {
                return c.JSON(wallet.Proof)
            }
        }

        return c.Status(http.StatusNotFound).SendString("Address not found")
    })

    log.Fatal(app.Listen(":3000"))
}
