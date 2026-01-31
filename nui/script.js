$(function () {
    const $container = $("#app");
    const $infoOverlay = $(".info-overlay");
    const $objName = $(".obj");

    window.addEventListener("message", function (event) {
        const item = event.data;

        if (item.type === "abrirBlitz") {
            $container.fadeIn(400).css("display", "flex");
        }

        if (item.type === "fecharBlitz") {
            $container.fadeOut(400);
        }

        if (item.type === "abrirInfo") {
            $objName.text(item.obj.toUpperCase());
            $infoOverlay.fadeIn(300).css("display", "flex");
        }

        if (item.type === "fecharInfo") {
            $infoOverlay.fadeOut(300);
        }
    });

    // Fechar com ESC
    document.onkeyup = function (data) {
        if (data.which == 27) {
            sendData("ButtonClick", { action: "fecharBlitz" });
        }
    };

    // Botões de ação (Colocar)
    $(document).on('click', '.colocar', function() {
        const type = $(this).val();
        const name = $(this).attr('name');
        setObstaculo(type, name);
    });

    // Botões de ação (Retirar)
    $(document).on('click', '.retirar', function() {
        const type = $(this).val();
        setObstaculo(type, "d");
    });

    // Limpar Área
    $("#clear-all").click(function () {
        sendData("ButtonClick", { action: "clearArea" });
    });

    function setObstaculo(obstaculo, nome) {
        sendData("ButtonClick", { action: "setObstaculo", obstaculo: obstaculo, nome: nome });
    }

    function sendData(name, data) {
        $.post(
            `http://${GetParentResourceName()}/${name}`,
            JSON.stringify(data),
            function (datab) {}
        );
    }
});
