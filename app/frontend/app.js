const API_URL = "http://localhost:5000";
const productForm = document.getElementById("product-form");
const productsTableBody = document.getElementById("products-table-body");
const errorMessage = document.getElementById("error-message");
const successMessage = document.getElementById("success-message");

function showError(message) {
    errorMessage.textContent = message;
    errorMessage.style.display = "block";

    successMessage.style.display = "none";
}

function showSuccess(message) {
    successMessage.textContent = message;
    successMessage.style.display = "block";

    errorMessage.style.display = "none";

    setTimeout(() => {
        successMessage.style.display = "none";
    }, 3000);
}

function clearMessages() {
    errorMessage.style.display = "none";
    successMessage.style.display = "none";
}

async function loadProducts() {

    try {

        clearMessages();

        const response = await fetch(`${API_URL}/items`);

        if (!response.ok) {
            throw new Error("Failed to load products");
        }

        const products = await response.json();

        productsTableBody.innerHTML = "";

        if (products.length === 0) {

            productsTableBody.innerHTML = `
                <tr>
                    <td colspan="3" class="empty">
                        No products found.
                    </td>
                </tr>
            `;

            return;
        }

        products.forEach(product => {

            const row = document.createElement("tr");

            row.innerHTML = `
                <td>${product.name}</td>
                <td>₹${Number(product.price).toFixed(2)}</td>
                <td>${product.stock}</td>
            `;

            productsTableBody.appendChild(row);
        });

    } catch (error) {

        console.error(error);

        productsTableBody.innerHTML = `
            <tr>
                <td colspan="3" class="empty">
                    Unable to load products.
                </td>
            </tr>
        `;

        showError(
            "Unable to connect to the API. Please check that the backend is running."
        );
    }
}
productForm.addEventListener("submit", async (event) => {

    event.preventDefault();

    clearMessages();

    const name = document.getElementById("name").value.trim();
    const price = document.getElementById("price").value;
    const stock = document.getElementById("stock").value;

    try {

        const response = await fetch(`${API_URL}/items`, {

            method: "POST",

            headers: {
                "Content-Type": "application/json"
            },

            body: JSON.stringify({
                name: name,
                price: Number(price),
                stock: Number(stock)
            })
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.error || "Failed to add product");
        }

        showSuccess("Product added successfully!");

        productForm.reset();

        await loadProducts();

    } catch (error) {

        console.error(error);

       showError(error.message || "Failed to add product.");
    }
});
loadProducts();
